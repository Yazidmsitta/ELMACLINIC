import { createHmac } from 'node:crypto';
import { expect,test } from 'vitest';
import { verifyCatalogRequest } from '../src/lib/integrations/catalog-auth';
const secret='ab'.repeat(32),timestamp='1789142400';
function signed(path='/api/v1/integrations/catalog?page=2'){
 const signature=createHmac('sha256',Buffer.from(secret,'hex')).update(`${timestamp}.GET.${path}`).digest('hex');
 return new Request(`https://api.example${path}`,{headers:{'x-elma-timestamp':timestamp,'x-elma-signature':`sha256=${signature}`}});
}
test('catalog signature binds exact query path and expires',()=>{
 expect(()=>verifyCatalogRequest(signed(),secret,Number(timestamp)*1000)).not.toThrow();
 expect(()=>verifyCatalogRequest(signed(),secret,(Number(timestamp)+301)*1000)).toThrow();
 const changed=new Request('https://api.example/api/v1/integrations/catalog?page=3',{headers:signed().headers});
 expect(()=>verifyCatalogRequest(changed,secret,Number(timestamp)*1000)).toThrow();
 expect(()=>verifyCatalogRequest(signed(),'cd'.repeat(32),Number(timestamp)*1000)).toThrow();
});
