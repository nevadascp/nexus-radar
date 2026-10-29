const NAMES=['axe','crystal_maiden','invoker','windrunner','sven','nevermore','antimage','phantom_assassin','lion','puck'];
const PLAYERS=['north','mira','nightshift','snow','atlas','echo','raven','luna','void','zen'];
const ABILITIES={axe:['axe_berserkers_call','axe_battle_hunger','axe_counter_helix','axe_culling_blade'],invoker:['invoker_quas','invoker_wex','invoker_exort','invoker_invoke'],crystal_maiden:['crystal_maiden_crystal_nova','crystal_maiden_frostbite','crystal_maiden_brilliance_aura','crystal_maiden_freezing_field'],windrunner:['windrunner_shackleshot','windrunner_powershot','windrunner_windrun','windrunner_focusfire'],sven:['sven_storm_bolt','sven_great_cleave','sven_warcry','sven_gods_strength']};
Object.assign(ABILITIES,{nevermore:['nevermore_shadowraze1','nevermore_necromastery','nevermore_dark_lord','nevermore_requiem'],antimage:['antimage_mana_break','antimage_blink','antimage_counterspell','antimage_mana_void'],phantom_assassin:['phantom_assassin_stifling_dagger','phantom_assassin_phantom_strike','phantom_assassin_blur','phantom_assassin_coup_de_grace'],lion:['lion_impale','lion_voodoo','lion_mana_drain','lion_finger_of_death'],puck:['puck_illusory_orb','puck_waning_rift','puck_phase_shift','puck_dream_coil']});
const BASE=[[-1200,-700],[-2300,-1300],[-200,-300],[-4800,2800],[900,-2400],[1200,900],[5100,-1800],[3100,2600],[1800,1800],[-2200,4200]];
export function demoSnapshot(elapsed=0,seq=1,paused=false){
  const t=1478+elapsed;
  const pos=NAMES.map((name,i)=>{const f=i===6?2:i===8?1:0;return {id:String(i+1),name:`npc_dota_hero_${name}`,team:i<5?2:3,x:BASE[i][0]+(f?0:Math.sin(elapsed*.24+i)*170),y:BASE[i][1]+(f?0:Math.cos(elapsed*.18+i)*130),f,seen:f?t-(i===6?22:4):undefined,hp:i===2?1260:i===5?820:1000+i*100,max_hp:i===2?1740:1500+i*90,mana:i===2?1040:400+i*55,max_mana:i===2?1390:700+i*65,alive:i!==9,respawn_at:i===9?1510:undefined,level:15+i%5,me:i===2};});
  const info={};
  for(let i=0;i<10;i++){
    const name=NAMES[i],abilities=ABILITIES[name]||[`${name}_ability_1`,`${name}_ability_2`,`${name}_ability_3`,`${name}_ability_4`];
    info[`h${i+1}`]={pn:PLAYERS[i],items:[{slot:0,name:'item_blink',ready_at:i===2?1489:0},{slot:1,name:'item_power_treads'},{slot:2,name:i===2?'item_black_king_bar':'item_magic_wand',charges:i===2?undefined:17,ready_at:i===2?1514:0},{slot:3,name:i===2?'item_ultimate_scepter':'item_force_staff'},{slot:4,name:'item_null_talisman'},{slot:5,name:'item_tpscroll',charges:2},{slot:6,name:'item_ward_observer',charges:2},{slot:16,name:'item_grove_bow'}],
      abilities:abilities.map((a,j)=>({name:a,level:j===3?2:4,ult:j===3,ready_at:i===2&&j===3?1484:0})),ult:{name:abilities[3],level:2,ready_at:i%3===0?1501:0},
      attr:{s:54+i*2,g:37+i,i:89+i*3,p:i===2?2:0,dmg:157+i*5,arm:9.3+i,ms:330,aps:1.42,rng:600,mr:25,hpr:5.2,mpr:8.1,xp:14680},
      stats:{k:[3,1,7,2,5,6,3,4,1,2][i],d:[2,3,1,2,2,3,2,4,5,4][i],a:4+i%5,nw:9300+i*470,g:1240+i*90,lh:145+i*7,dn:7+i,dmg:9600,heal:0},buyback:{ready_at:i%3?0:1598},seen_at:t,
      mods:i===2?[{name:'modifier_invoker_quas_instance',stacks:3}]:[]};
  }
  return {schema:2,seq,matchId:'demo-match',clock:{t,ms:t,in_game:true,paused,team:2,day:true,cyc:1800},pos,info,
    wards:[{x:-1200,y:2200,team:2,kind:'observer',f:0,r:1600,e:1700},{x:2400,y:1400,team:3,kind:'observer',f:1,r:1600,e:1660},{x:200,y:-1300,team:2,kind:'sentry',f:0,r:900,e:1740}],
    runes:[{x:-1800,y:700,rune_type:0,f:0},{x:2400,y:-2100,rune_type:5,f:1}],
    units:[{kind:'building',b:'fort',x:-6600,y:-6400,team:2,hp:100,f:0},{kind:'building',b:'fort',x:6500,y:5900,team:3,hp:100,f:0},...[-1,1].flatMap((s)=>[{kind:'building',b:'t1',x:s*1500,y:s*1400,team:s<0?2:3,hp:72,f:0},{kind:'building',b:'t2',x:s*4200,y:s*3600,team:s<0?2:3,hp:100,f:0}]),{kind:'courier',x:-4000,y:-3000,team:2,f:0},...Array.from({length:14},(_,i)=>({kind:'creep',x:-500+i*90,y:-700+i*65,team:i<7?2:3,f:0}))],
    camps:[{x:-3900,y:-1300,t:2,s:1,n:3},{x:-5200,y:500,t:1,s:1,n:4},{x:3000,y:2900,t:2,s:0,n:0},{x:4600,y:1300,t:3,s:1,n:3},{x:-1500,y:-3600,t:1,s:1,n:4},{x:1700,y:4100,t:2,s:1,n:3}],
    events:[{id:'scan',kind:'scan',x:2700,y:1600,team:2,t0:t-2,te:t+4}],objectives:{roshan:{alive:true,hp:100,under_attack:false,x:7400,y:-7100,attackers:[]},tormentors:[{id:'1',alive:true,hp:100,under_attack:false}],glyph_radiant:0,glyph_dire:1530,scan_radiant:1499,scan_dire:0,scan_charges:{r:1,d:2},stock:{smoke:1,obs:2,sen:5}},quality:{work_ms:.7,upload_ms:18,bytes:2100}};
}
export const DEMO_FEED=[
  {key:'demo0009',k:'tp_to',h:'npc_dota_hero_invoker',t:1474,p:'mid_c',x:-200,y:-300,s:'a'},
  {key:'demo0008',k:'ward',h:'npc_dota_hero_lion',t:1467,p:'top_d',w:'o',x:2400,y:1400,s:'e'},
  {key:'demo0007',k:'ult',h:'npc_dota_hero_axe',a:'axe_culling_blade',t:1455,p:'mid_c',s:'a'},
  {key:'demo0006',k:'death',h:'npc_dota_hero_puck',t:1451,r:59,s:'e'},
  {key:'demo0005',k:'rune',h:'npc_dota_hero_windrunner',t:1440,a:0,p:'top_c',s:'a'},
  {key:'demo0004',k:'smoke',h:'npc_dota_hero_nevermore',t:1425,p:'mid_d',s:'e'},
  {key:'demo0003',k:'glyph',t:1418,team:'d'},
  {key:'demo0002',k:'boss_calm',b:'rosh',t:1406,v:100},
  {key:'demo0001',k:'tower',team:'d',t:1394,p:'t1_bot',s:'e'}
];
export function startDemo(onSnapshot,onEvent){const began=performance.now();let seq=0;for(const e of DEMO_FEED)onEvent(e.key,e);const step=()=>onSnapshot(demoSnapshot((performance.now()-began)/1000,++seq));step();const timer=setInterval(step,100);return()=>clearInterval(timer);}
