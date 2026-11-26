import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req => {
 const secret=Deno.env.get('HH_CLEANUP_SECRET');
 if(req.method!=='POST'||!secret||req.headers.get('x-hh-cleanup')!==secret) return new Response('Forbidden',{status:403});
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
 const {data,error}=await db.rpc('hh_photo_expired');
 if(error)return new Response(error.message,{status:500});
 const paths=data.map((r:{path:string})=>r.path);
 if(paths.length){const {error}=await db.storage.from('hh-photos').remove(paths);if(error)return new Response(error.message,{status:500});}
 return Response.json({removed:paths.length});
});
