import 'server-only';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { HttpError } from '../http';

export function verifyCatalogRequest(request:Request,secret:string,now=Date.now()) {
  if (!/^[a-f0-9]{64}$/i.test(secret)) throw new Error('Invalid catalog configuration');
  const timestamp=request.headers.get('x-elma-timestamp')??'',signature=request.headers.get('x-elma-signature')??'';
  if(request.method!=='GET'||!/^\d{10}$/.test(timestamp)||!/^sha256=[a-f0-9]{64}$/i.test(signature)
    ||Math.abs(Math.floor(now/1000)-Number(timestamp))>300) throw new HttpError(401,'Signature invalide ou expirée.');
  const url=new URL(request.url);
  const expected=createHmac('sha256',Buffer.from(secret,'hex')).update(`${timestamp}.GET.${url.pathname}${url.search}`).digest();
  if(!timingSafeEqual(expected,Buffer.from(signature.slice(7),'hex')))throw new HttpError(401,'Signature invalide ou expirée.');
}
