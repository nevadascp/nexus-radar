export const PROTOCOL = 2;
export const MAX_HEROES = 64;
export const finite = (v, fallback = null) => typeof v === 'number' && Number.isFinite(v) ? v : fallback;
export const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
export const values = (v, limit = 512) => (Array.isArray(v) ? v : v && typeof v === 'object' ? Object.values(v) : []).filter(v => v && typeof v === 'object').slice(0, limit);
export const text = (v, max = 160) => typeof v === 'string' ? v.slice(0, max) : '';
export const escapeHTML = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const heroKey = v => text(v, 100).replace(/^npc_dota_hero_/, '');
export const numberText = v => finite(v) === null ? '—' : Math.round(v).toLocaleString('ru-RU');
export const compact = v => finite(v) === null ? '—' : Math.abs(v) >= 1000 ? `${(v / 1000).toFixed(1)}k` : String(Math.round(v));
export function clockText(v) { if (finite(v) === null) return '—:—'; const n = Math.floor(Math.abs(v)); return `${v < 0 ? '−' : ''}${Math.floor(n/60)}:${String(n%60).padStart(2,'0')}`; }
export function countdown(v) { if (finite(v) === null) return '—'; if (v <= 0) return 'Готово'; return v >= 60 ? clockText(Math.ceil(v)) : String(Math.ceil(v)); }
export function parseSession(hash) { const p = new URLSearchParams(String(hash).replace(/^#/, '')); const id = p.get('s'); return /^[a-f0-9]{32}$/.test(id || '') ? id : null; }
export function validateConfig(value) {
  const f = value?.firebase;
  if (value?.protocol !== PROTOCOL || !f || !text(f.projectId, 100) || !text(f.apiKey, 200)) return false;
  try { const u = new URL(f.databaseURL); return u.protocol === 'https:' && /\.(firebasedatabase\.app|firebaseio\.com)$/.test(u.hostname); } catch { return false; }
}

const safeName = v => /^[a-zA-Z0-9_]{1,100}$/.test(v || '') ? v : '';
function normalizeInfo(raw) {
  const out = {};
  if (!raw || typeof raw !== 'object') return out;
  for (const [id, h] of Object.entries(raw).slice(0,MAX_HEROES)) {
    if (!/^h\d{1,10}$/.test(id) || !h || typeof h !== 'object') continue;
    const info = {pn:text(h.pn, 80),items:[],abilities:[],mods:[]};
    for (const item of values(h.items, 24)) {
      if (!Number.isInteger(item.slot) || item.slot < 0 || item.slot > 20 || !safeName(item.name)) continue;
      info.items.push({slot:item.slot,name:item.name,ready_at:finite(item.ready_at),charges:finite(item.charges),o:item.o === 1,seen_at:finite(item.seen_at)});
    }
    for (const a of values(h.abilities,12)) {
      if (!safeName(a.name)) continue;
      info.abilities.push({name:a.name,level:clamp(finite(a.level,0),0,9),ready_at:finite(a.ready_at),charges:finite(a.charges),ult:a.ult === true});
    }
    if (h.ult && safeName(h.ult.name)) info.ult={name:h.ult.name,level:finite(h.ult.level,0),ready_at:finite(h.ult.ready_at)};
    if (h.buyback && typeof h.buyback === 'object') info.buyback={ready_at:finite(h.buyback.ready_at)};
    if (h.stats && typeof h.stats === 'object') {
      info.stats={}; for (const k of ['k','d','a','nw','lh','dn','g','dmg','heal','obs','sen','stk']) info.stats[k]=finite(h.stats[k]);
      info.stats.partial=h.stats.partial === true; info.stats.est=h.stats.est === 1;
    }
    if (h.attr && typeof h.attr === 'object') { info.attr={}; for (const k of ['s','g','i','p','dmg','dmx','aps','rng','arm','mr','ms','hpr','mpr','xp']) info.attr[k]=finite(h.attr[k]); }
    for (const m of values(h.mods,24)) if (safeName(m.name)) info.mods.push({name:m.name,ends_at:finite(m.ends_at),stacks:finite(m.stacks)});
    info.seen_at=finite(h.seen_at);
    out[id]=info;
  }
  return out;
}
function mapRows(raw, limit=512) {
  return values(raw,limit).filter(r => finite(r.x) !== null && finite(r.y) !== null && Math.abs(r.x) <= 50000 && Math.abs(r.y) <= 50000).map(r => {
    const row={...r,x:r.x,y:r.y}; row.kind=text(r.kind,30); row.name=text(r.name,100); return row;
  });
}
export function normalizeLive(raw) {
  if (!raw || typeof raw !== 'object') return null;
  if (raw.schema !== PROTOCOL) throw new Error('PROTOCOL_MISMATCH');
  if (!Number.isSafeInteger(raw.seq) || raw.seq < 1) throw new Error('INVALID_SEQUENCE');
  const c=raw.clock;
  if (!c || finite(c.t) === null) throw new Error('INVALID_CLOCK');
  const pos=[];
  for (const h of values(raw.pos,MAX_HEROES)) {
    const id=String(h.id);
    if (!/^\d{1,10}$/.test(id) || !/^npc_dota_hero_[a-z0-9_]{1,70}$/.test(h.name || '') || finite(h.x) === null || finite(h.y) === null || Math.abs(h.x)>50000 || Math.abs(h.y)>50000) continue;
    pos.push({...h,id,name:h.name,x:h.x,y:h.y,team:h.team===2?2:h.team===3?3:1,f:[0,1,2].includes(h.f)?h.f:2,
      hp:finite(h.hp),max_hp:finite(h.max_hp),mana:finite(h.mana),max_mana:finite(h.max_mana),level:finite(h.level),seen:finite(h.seen),tp:finite(h.tp),respawn_at:finite(h.respawn_at),alive:h.alive !== false,me:h.me === true});
  }
  return {schema:PROTOCOL,seq:raw.seq,matchId:text(String(raw.matchId ?? ''),80),clock:{t:c.t,ms:finite(c.ms,c.t),in_game:c.in_game === true,paused:c.paused === true,day:c.day !== false,ns:c.ns === true,cyc:finite(c.cyc),team:finite(c.team,1)},
    pos,info:normalizeInfo(raw.info),units:mapRows(raw.units),wards:mapRows(raw.wards),runes:mapRows(raw.runes,64),camps:mapRows(raw.camps,256),events:mapRows(raw.events,128),
    objectives:raw.objectives && typeof raw.objectives==='object'?raw.objectives:{},quality:raw.quality && typeof raw.quality==='object'?raw.quality:{}};
}

export class RoomStore {
  constructor() { this.clear(); }
  clear() { this.live=null;this.lastSequence=0;this.frames=[];this.receivedAt=0;this.intervals=[];this.match='';this.samples=0; }
  accept(raw, now=performance.now()) {
    const next=normalizeLive(raw); if (!next || next.seq <= this.lastSequence) return false;
    if (this.match && this.match !== next.matchId) {this.frames=[];this.intervals=[];}
    const sourceTime=next.clock.ms;
    if (this.receivedAt && now>this.receivedAt) {this.intervals.push(now-this.receivedAt);if(this.intervals.length>30)this.intervals.shift();}
    if (next.clock.in_game) { this.frames.push({t:sourceTime,rows:new Map(next.pos.map(h=>[h.id,h]))});if(this.frames.length>10)this.frames.shift(); }
    else this.frames=[];
    this.match=next.matchId;this.live=next;this.lastSequence=next.seq;this.receivedAt=now;this.samples++;
    return true;
  }
  gameTime(now=performance.now()) { if (!this.live) return 0; const c=this.live.clock; return c.ms+(!c.in_game||c.paused?0:Math.min(5,Math.max(0,now-this.receivedAt)/1000)); }
  rate() { return this.intervals.length?1000/(this.intervals.reduce((a,b)=>a+b,0)/this.intervals.length):0; }
  position(id, now=performance.now(), lowLatency=true) {
    const current=this.live?.pos.find(h=>h.id===id); if(!current)return null;
    if (current.f || this.live.clock.paused || this.frames.length<2) return [current.x,current.y];
    const avg=this.intervals.length?this.intervals.reduce((a,b)=>a+b,0)/this.intervals.length/1000:.1;
    const render=this.gameTime(now)-(lowLatency?0:clamp(avg*1.2,.04,.18));
    let a,b;
    for(let i=this.frames.length-1;i>0;i--) {if(render>=this.frames[i-1].t){a=this.frames[i-1];b=this.frames[i];break;}}
    if(!a||!b){a=this.frames[0];b=this.frames[1];}
    const x=a.rows.get(id),y=b.rows.get(id);
    if(!x||!y||x.f!==y.f||Math.hypot(y.x-x.x,y.y-x.y)>1800||b.t<=a.t)return [current.x,current.y];
    const dt=b.t-a.t;
    const factor=clamp((render-a.t)/dt,0,1+Math.min(.08/dt,.6));
    return [x.x+(y.x-x.x)*factor,x.y+(y.y-x.y)*factor];
  }
}

export const eventCategory = e => ['tp_from','tp_to','spot','farm'].includes(e.k)?'move':['death','ability','ult','smoke','blink'].includes(e.k)?'fight':'objective';
export class FeedStore {
  constructor(){this.entries=new Map();}
  set(key,raw){if(!/^[a-zA-Z0-9_-]{1,80}$/.test(key)||!raw||typeof raw!=='object')return false;const isNew=!this.entries.has(key);this.entries.set(key,{...raw,k:text(raw.k,30),h:text(raw.h,100),a:typeof raw.a==='number'?raw.a:text(raw.a,100),p:text(raw.p,160),t:finite(raw.t,0),x:finite(raw.x),y:finite(raw.y)});while(this.entries.size>100)this.entries.delete([...this.entries.keys()].sort()[0]);return isNew;}
  delete(key){this.entries.delete(key);}
  clear(){this.entries.clear();}
  list(filter='all'){return [...this.entries.entries()].sort(([a],[b])=>b.localeCompare(a)).filter(([,e])=>filter==='all'||eventCategory(e)===filter);}
}

export function teamTotals(live,team){const out={kills:0,nw:0,hasKills:false,hasNw:false,partial:false};for(const h of live?.pos||[]){if(h.team!==team)continue;const s=live.info[`h${h.id}`]?.stats;if(!s)continue;if(finite(s.k)!==null){out.kills+=s.k;out.hasKills=true;}if(finite(s.nw)!==null){out.nw+=s.nw;out.hasNw=true;out.partial ||= s.partial;}}return out;}
