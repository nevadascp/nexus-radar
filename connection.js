import {validateConfig,PROTOCOL} from './model.js';
export async function connectRoom(config,id,callbacks){
  if(!validateConfig(config))throw new Error('NOT_CONFIGURED');
  const [{initializeApp,getApps},{getDatabase,ref,onValue,query,limitToLast,onChildAdded,onChildChanged,onChildRemoved}]=await Promise.all([
    import('https://www.gstatic.com/firebasejs/13.1.0/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/13.1.0/firebase-database.js')
  ]);
  const name='nexus-viewer';const app=getApps().find(a=>a.name===name)||initializeApp(config.firebase,name);const db=getDatabase(app),base=`sessions/${id}`,off=[];let stopped=false,seen=false,connected=false;
  const terminate=(status,error)=>{if(stopped)return;stopped=true;callbacks.clear?.();callbacks.status(status,error);queueMicrotask(()=>{for(const fn of off)fn();});};
  const fail=error=>{if(stopped)return;const code=String(error?.code||'').toLowerCase();if(code.includes('permission'))terminate('closed',error);else callbacks.status('error',error);};
  callbacks.status('connecting');
  off.push(onValue(ref(db,'.info/connected'),snap=>{connected=snap.val()===true;if(stopped)return;callbacks.status(connected?(seen?'online':'connecting'):'offline');},fail));
  off.push(onValue(ref(db,'.info/serverTimeOffset'),snap=>callbacks.offset?.(Number(snap.val())||0)));
  off.push(onValue(ref(db,`${base}/meta`),snap=>{if(stopped)return;const m=snap.val();if(!m||m.active!==true){terminate('closed');return;}if(m.protocol!==PROTOCOL){terminate('protocol');return;}seen=true;callbacks.meta?.(m);callbacks.status(connected?'online':'offline');},fail));
  off.push(onValue(ref(db,`${base}/live`),snap=>{if(stopped)return;const live=snap.val();if(live)callbacks.snapshot(live);else callbacks.status('waiting');},fail));
  const feed=query(ref(db,`${base}/feed`),limitToLast(100));
  off.push(onChildAdded(feed,s=>!stopped&&callbacks.event(s.key,s.val())));
  off.push(onChildChanged(feed,s=>!stopped&&callbacks.event(s.key,s.val())));
  off.push(onChildRemoved(feed,s=>!stopped&&callbacks.removeEvent(s.key)));
  return()=>{stopped=true;for(const fn of off)fn();};
}
