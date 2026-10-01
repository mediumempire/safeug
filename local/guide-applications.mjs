export async function guideApplications({path,method,input,actor,db,realtime,reply}) {
  const get=db.prepare('SELECT data FROM records WHERE collection=? AND id=?');
  const put=db.prepare('INSERT OR REPLACE INTO records VALUES(?,?,?)');
  const now=new Date().toISOString();
  if(path==='/api/guideApplications' && method==='POST') {
    if(actor.role==='admin')return reply(403,{error:'Apply from the mobile app'});
    if(input?.consent!==true)return reply(400,{error:'Agree to share your application with SafeUG administrators'});
    const data={};
    for(const key of ['name','phone','email','area','description','languages','license']) {
      if(typeof input[key]!=='string' || input[key].length>(key==='description'?2000:200))return reply(400,{error:`Invalid ${key}`});
      data[key]=input[key].trim();
    }
    if(!data.name || !data.area || !data.description || !/^\+[1-9]\d{6,14}$/.test(data.phone) || (data.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)))return reply(400,{error:'Provide your name, service area, introduction and WhatsApp number with country code'});
    const id=`guideapp_${actor.id}`;
    const previous=get.get('guideApplications',id);
    if(previous && JSON.parse(previous.data).status==='Approved')return reply(409,{error:'Your application is already approved. Contact administration to update your listing.'});
    const record={...data,id,ownerId:actor.id,status:'Pending',consentAt:now,createdAt:previous?JSON.parse(previous.data).createdAt:now,updatedAt:now};
    put.run('guideApplications',id,JSON.stringify(record));
    realtime.changed('guideApplications',record);
    return reply(previous?200:201,record);
  }
  const review=path.match(/^\/api\/guideApplications\/(guideapp_[a-f0-9]+)\/review$/);
  if(review && method==='POST') {
    if(actor.role!=='admin')return reply(403,{error:'Administrator permission required'});
    if(!['Approved','Rejected'].includes(input?.status) || typeof input.note!=='string' || input.note.length>1000)return reply(400,{error:'Choose Approved or Rejected and provide a review note'});
    const row=get.get('guideApplications',review[1]);
    if(!row)return reply(404,{error:'Application not found'});
    const record=JSON.parse(row.data);
    const guideId=`guide_${record.ownerId}`;
    const previous=get.get('guides',guideId);
    const guide=previous?JSON.parse(previous.data):{id:guideId,createdAt:now};
    Object.assign(record,{status:input.status,reviewNote:input.note.trim(),reviewedAt:now,updatedAt:now});
    Object.assign(guide,{name:record.name,phone:record.phone,area:record.area,description:record.description,languages:record.languages,status:input.status==='Approved'?'Active':'Inactive',updatedAt:now});
    db.exec('BEGIN');
    try{put.run('guideApplications',record.id,JSON.stringify(record)); if(input.status==='Approved'||previous)put.run('guides',guideId,JSON.stringify(guide));db.exec('COMMIT');}catch(error){db.exec('ROLLBACK');throw error;}
    realtime.changed('guideApplications',record);
    realtime.changed('guides',guide);
    return reply(200,record);
  }
  return reply(405,{error:'Use the guide application submission or review flow'});
}
