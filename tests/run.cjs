const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { LuaFactory } = require('wasmoon');
async function main() {
  const root = path.resolve(__dirname, '..');
  const factory = new LuaFactory();
  const files = [];
  function scan(dir) {
    for (const entry of fs.readdirSync(path.join(root, dir), {withFileTypes:true})) {
      if (['node_modules','.tools','.git','data'].includes(entry.name)) continue;
      const file = path.join(dir,entry.name).replaceAll('\\','/');
      if (entry.isDirectory()) scan(file); else if (file.endsWith('.lua')) files.push(file);
    }
  }
  scan('');
  for (const file of files) await factory.mountFile('/repo/'+file,fs.readFileSync(path.join(root,file)));
  const lua = await factory.createEngine({enableProxy:false});
  try {
    const codec = process.argv.indexOf('--codec');
    if (codec >= 0) { await factory.mountFile('/codec.lua',fs.readFileSync(process.argv[codec+1])); await lua.doFile('/codec.lua'); }
    else {
      lua.global.set('__quote',v=>JSON.stringify(v));
      // Preserve numeric-looking object keys: Wasmoon's object bridge coerces "1".
      const quote = value => '"'+[...Buffer.from(value)].map(byte=>'\\'+String(byte).padStart(3,'0')).join('')+'"';
      const literal = value => {
        if (value===null) throw new Error('null outside contract');
        if (typeof value==='string') return quote(value);
        if (typeof value!=='object') return String(value);
        const entries=Array.isArray(value)?value.map((v,i)=>`[${i+1}]=${literal(v)}`):Object.entries(value).map(([k,v])=>`[${quote(k)}]=${literal(v)}`);
        return '{'+entries.join(',')+'}';
      };
      lua.global.set('__decode',s=>'return '+literal(JSON.parse(s)));
      await lua.doString(`
        local function encode(value)
          local kind=type(value)
          if kind=='string' then return __quote(value) end
          if kind=='number' then assert(value==value and value~=math.huge and value~=-math.huge);return string.format('%.17g',value) end
          if kind=='boolean' then return tostring(value) end
          assert(kind=='table','Unsupported JSON value')
          local array,count=true,0
          for key in pairs(value) do count=count+1;if type(key)~='number' or key%1~=0 or key<1 then array=false end end
          array=array and count>0 and count==#value
          local parts={}
          if array then for _,v in ipairs(value) do parts[#parts+1]=encode(v) end
          else for k,v in pairs(value) do assert(type(k)=='string');parts[#parts+1]=__quote(k)..':'..encode(v) end end
          return (array and '[' or '{')..table.concat(parts,',')..(array and ']' or '}')
        end
        json={encode=encode,decode=function(s) return assert(load(__decode(s),'fixture','t',{}))(),#s+1 end}
      `);
    }
    lua.global.set('__files',files);
    lua.global.set('__report',(name,ok,err)=>console.log(`${ok?'PASS':'FAIL'} ${name}${ok?'':': '+err}`));
    await lua.doFile('/repo/tests/admin_access_spec.lua');
    assert.equal(lua.global.get('__failures'),0);
  } finally { lua.global.close(); }
}
main().catch(error=>{console.error(error);process.exitCode=1;});
