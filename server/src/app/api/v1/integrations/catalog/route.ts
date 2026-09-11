import { createHmac } from 'node:crypto';
import { z } from 'zod';
import { privilegedDatabase } from '../../../../../lib/supabase';
import { handle,HttpError,json } from '../../../../../lib/http';
import { verifyCatalogRequest } from '../../../../../lib/integrations/catalog-auth';
export const runtime='nodejs';
export async function GET(request:Request){return handle(async()=>{
  if(process.env.WEBSITE_CATALOG_ENABLED!=='true')throw new HttpError(503,'Catalogue externe désactivé.');
  const secret=process.env.WEBSITE_CATALOG_SECRET_HEX,limiter=process.env.RATE_LIMIT_SECRET;
  if(!secret||!limiter||limiter.length<32)throw new Error('Missing catalog configuration');
  verifyCatalogRequest(request,secret);
  const page=z.coerce.number().int().min(1).max(100000).parse(new URL(request.url).searchParams.get('page')??1);
  const db=privilegedDatabase();
  const limit=await db.rpc('consume_auth_limit',{bucket_key:createHmac('sha256',limiter).update('website-catalog:v1').digest('hex'),maximum:60});
  if(limit.error)throw new Error('Limiter unavailable');
  if(!limit.data){const response=json({message:'Trop de requêtes.'},429);response.headers.set('Retry-After','60');return response;}
  const result=await db.rpc('website_catalog',{page_number:page});
  if(result.error)throw new Error('Catalog unavailable');
  return json(result.data);
});}
