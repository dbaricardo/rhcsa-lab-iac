'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const file = path.join(__dirname, '..', 'index.html');
function source() { return fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : ''; }
function helpers() {
  const html = source();
  const match = html.match(/<script id="app">([\s\S]*?)<\/script>/);
  assert.ok(match, 'self-contained app script exists');
  const context = {module:{exports:{}}, Intl, Date, console, setTimeout, clearTimeout};
  vm.runInNewContext(match[1], context, {filename:'index.html'});
  return context.module.exports;
}
function task(overrides={}) {
  return {id:'users',number:2,title:'Usuários',host:'servera',hosts:['servera'],description:'Criar usuários.',instructions:['Execute no host indicado.'],warning:'',solve_target:'servera · 192.168.56.20',solve_method:'ssh',solve_command:'ssh servera',solve_note:'Resolva esta tarefa na servera.',status:'pending',passed_criteria:0,total_criteria:0,last_grade_at:null,last_action:null,attempts:0,criteria:[],output:'',history:[],...overrides};
}
function state(tasks=[task()], overrides={}) {
  return {tasks,summary:{total:tasks.length,passed:0,pending:tasks.length,in_progress:0,failed:0,error:0},next_task:tasks[0]?.id??null,updated_at:null,...overrides};
}
test('API contract accepts actual state and rejects malformed or unsafe payloads', () => {
  const {validateState} = helpers();
  assert.equal(validateState(state()).tasks[0].id,'users');
  assert.equal(validateState(state([])).tasks.length,0);
  for (const invalid of [null,{},state([task({status:'done'})]),state([task({id:'users; reboot'})]),state([task({criteria:[{ok:'true',text:'x'}]})]),state([task({instructions:null})]),state([task(),task()]),state(undefined,{next_task:'missing'}),state(undefined,{summary:{total:1}}),state([task({passed_criteria:3,total_criteria:2})]),state([task({solve_target:null})]),state([task({solve_method:'web-shell'})]),state([task({solve_method:'console',solve_command:'ssh servera'})]),state([task({history:[{action:'finish',status:'failed',at:'2026-09-23T14:10:00Z',returncode:0,passed_criteria:0,total_criteria:1,failure_reasons:['x'.repeat(301)]}]})])]) {
    assert.throws(()=>validateState(invalid), /inválid/i);
  }
});
class Element {
  constructor(tag='div') {this.tagName=tag;this.children=[];this.attributes={};this.dataset={};this.style={};this.textContent='';this.value='';this.hidden=false;this.listeners={};this.scrollTop=0;this.disabled=false;}
  setAttribute(k,v) {this.attributes[k]=String(v);}
  getAttribute(k) {return this.attributes[k];}
  append(...nodes) {this.children.push(...nodes);}
  replaceChildren(...nodes) {this.children=nodes;}
  addEventListener(k,fn) {this.listeners[k]=fn;}
  focus() {this.ownerDocument.activeElement=this;}
  select() {this.selected=true;}
  remove() {}
}
function dom() {
  const nodes=new Map();
  const doc={activeElement:null,body:new Element('body'),getElementById(id){if(!nodes.has(id)){const el=new Element();el.ownerDocument=doc;nodes.set(id,el);}return nodes.get(id);},createElement(tag){const el=new Element(tag);el.ownerDocument=doc;return el;},createTextNode(text){return {nodeType:3,textContent:String(text)};},querySelectorAll(){return [];},execCommand(){return true;}};
  return doc;
}
function setup(saved=null) {
  const doc=dom(),stored=new Map(saved ? [['rhcsa.selectedTask',saved]]:[]),announcements=[];
  const env={storage:{getItem:k=>stored.get(k)||null,setItem:(k,v)=>stored.set(k,v)},navigator:{},now:()=>new Date('2026-09-23T14:30:00Z')};
  const app=helpers().createDashboard(doc,env);
  return {doc,app,env,stored,announcements};
}
test('automatic attempt stopwatch derives running, finished and restarted windows from history', () => {
  const {attemptStopwatch,formatDuration} = helpers();
  const now = new Date('2026-09-23T14:30:00Z'), plain=value=>JSON.parse(JSON.stringify(value));
  assert.equal(formatDuration(0),'00:00:00');
  assert.equal(formatDuration(3661000),'01:01:01');
  assert.deepEqual(plain(attemptStopwatch([],now)),{state:'waiting',elapsedMs:0,startedAt:null,endedAt:null});
  const running=[
    {action:'start',status:'in_progress',at:'2026-09-23T14:00:00Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'grade',status:'failed',at:'2026-09-23T14:10:00Z',returncode:1,passed_criteria:2,total_criteria:6},
  ];
  assert.deepEqual(plain(attemptStopwatch(running,now)),{state:'running',elapsedMs:1800000,startedAt:'2026-09-23T14:00:00Z',endedAt:null});
  const finished=[...running,{action:'finish',status:'failed',at:'2026-09-23T14:20:00Z',returncode:0,passed_criteria:2,total_criteria:6}];
  assert.deepEqual(plain(attemptStopwatch(finished,now)),{state:'finished',elapsedMs:1200000,startedAt:'2026-09-23T14:00:00Z',endedAt:'2026-09-23T14:20:00Z'});
  const restarted=[...finished,{action:'start',status:'in_progress',at:'2026-09-23T14:25:00Z',returncode:0,passed_criteria:0,total_criteria:0}];
  assert.deepEqual(plain(attemptStopwatch(restarted,now)),{state:'running',elapsedMs:300000,startedAt:'2026-09-23T14:25:00Z',endedAt:null});
  assert.equal(attemptStopwatch([{...running[0],returncode:1}],now).state,'waiting','failed start does not run the timer');
});

test('completed attempt history retains every closed window with duration and last grade result', () => {
  const {completedAttempts,formatDuration} = helpers();
  const history=[
    {action:'start',status:'in_progress',at:'2026-09-23T13:00:00Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'grade',status:'passed',at:'2026-09-23T13:14:00Z',returncode:0,passed_criteria:6,total_criteria:6},
    {action:'finish',status:'passed',at:'2026-09-23T13:15:30Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'start',status:'in_progress',at:'2026-09-23T14:00:00Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'grade',status:'failed',at:'2026-09-23T14:08:00Z',returncode:1,passed_criteria:2,total_criteria:6,failure_reasons:['porta 82 não liberada','file1 ainda com user_home_t']},
    {action:'finish',status:'failed',at:'2026-09-23T14:10:00Z',returncode:0,passed_criteria:0,total_criteria:0,failure_reasons:[]},
    {action:'start',status:'in_progress',at:'2026-09-23T14:20:00Z',returncode:0,passed_criteria:0,total_criteria:0},
  ];
  const plain=value=>JSON.parse(JSON.stringify(value));
  assert.deepEqual(plain(completedAttempts(history)),[
    {startedAt:'2026-09-23T13:00:00Z',endedAt:'2026-09-23T13:15:30Z',elapsedMs:930000,status:'passed',failure_reasons:[]},
    {startedAt:'2026-09-23T14:00:00Z',endedAt:'2026-09-23T14:10:00Z',elapsedMs:600000,status:'failed',failure_reasons:['porta 82 não liberada','file1 ainda com user_home_t']},
  ]);
  assert.equal(formatDuration(completedAttempts(history)[0].elapsedMs),'00:15:30');
  assert.deepEqual(plain(completedAttempts([{action:'finish',status:'failed',at:'2026-09-23T14:10:00Z',returncode:0}])),[],'finish without a successful start is ignored');
});

test('real renderer preserves selection, focus and grade output across updates and explicit next', () => {
  const {doc,app,stored}=setup();
  const initial=state([task(),task({id:'storage',number:22,title:'Storage'})]);
  app.applyState(initial);
  assert.equal(app.selectedId,'users');
  assert.equal(doc.getElementById('task-title').textContent,'Usuários');
  assert.equal(doc.getElementById('solve-target').textContent,'servera · 192.168.56.20');
  assert.equal(doc.getElementById('solve-command').textContent,'ssh servera');
  assert.equal(doc.getElementById('solve-note').textContent,'Resolva esta tarefa na servera.');
  assert.equal(doc.getElementById('grade-command').textContent,'lab grade users');
  assert.equal(doc.getElementById('criteria-empty').textContent,'Ainda não avaliada');
  const focus=doc.getElementById('search');focus.focus();focus.value='usu';
  const output=doc.getElementById('output');output.scrollTop=80;
  const graded=state([task({status:'passed',last_grade_at:'2026-09-23T14:00:00Z',passed_criteria:1,total_criteria:1,criteria:[{ok:true,text:'<img src=x onerror=alert(1)>'}],output:'PASS <script>evil</script>',attempts:1,history:[{action:'grade',status:'passed',at:'2026-09-23T14:00:00Z',returncode:0,passed_criteria:1,total_criteria:1}]}),initial.tasks[1]],{next_task:'storage',summary:{total:2,passed:1,pending:1,in_progress:0,failed:0,error:0}});
  const originalRow=doc.getElementById('task-list').children[0];
  app.applyState(graded);
  assert.equal(app.selectedId,'users','grade must not jump selection');
  assert.equal(output.textContent,'PASS <script>evil</script>');
  assert.equal(output.scrollTop,80);
  assert.equal(doc.activeElement,focus);
  assert.equal(doc.getElementById('task-list').children[0],originalRow,'sidebar nodes remain stable');
  assert.equal(doc.getElementById('criteria').children[0].children[1].textContent,'<img src=x onerror=alert(1)>');
  assert.equal(doc.getElementById('task-status').textContent,'Aprovada');
  assert.equal(doc.getElementById('history-list').children.length,1);
  doc.getElementById('next-task').listeners.click();
  assert.equal(app.selectedId,'storage');
  assert.equal(stored.get('rhcsa.selectedTask'),'storage');
  assert.equal(setup('storage').app.applyState(initial),'storage');
  app.applyState(state([]));
  assert.equal(doc.getElementById('task-detail').hidden,true);
  assert.match(doc.getElementById('empty-state').textContent,/Nenhuma tarefa/);
  assert.doesNotMatch(source(), /\.innerHTML\s*=/);
});
test('stopwatch renders from persisted history and refreshes independently from polling', () => {
  const {doc,app,env}=setup();
  const running=task({status:'in_progress',last_action:'grade',history:[
    {action:'start',status:'in_progress',at:'2026-09-23T14:00:00Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'grade',status:'failed',at:'2026-09-23T14:10:00Z',returncode:1,passed_criteria:2,total_criteria:6},
  ]});
  app.applyState(state([running],{summary:{total:1,passed:0,pending:0,in_progress:1,failed:0,error:0}}));
  assert.equal(doc.getElementById('stopwatch-value').textContent,'00:30:00');
  assert.equal(doc.getElementById('stopwatch-state').textContent,'Em andamento');
  assert.equal(doc.getElementById('stopwatch').dataset.state,'running');
  env.now=()=>new Date('2026-09-23T14:30:05Z');
  app.refreshStopwatch();
  assert.equal(doc.getElementById('stopwatch-value').textContent,'00:30:05');
  const finished=task({...running,status:'failed',last_action:'finish',history:[...running.history,{action:'finish',status:'failed',at:'2026-09-23T14:20:00Z',returncode:0,passed_criteria:2,total_criteria:6}]});
  app.applyState(state([finished],{summary:{total:1,passed:0,pending:0,in_progress:0,failed:1,error:0}}));
  assert.equal(doc.getElementById('stopwatch-value').textContent,'00:20:00');
  assert.equal(doc.getElementById('stopwatch-state').textContent,'Encerrada');
});

test('completed duration history renders closed attempts separately from the live timer', () => {
  const {doc,app}=setup();
  const history=[
    {action:'start',status:'in_progress',at:'2026-09-23T13:00:00Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'grade',status:'passed',at:'2026-09-23T13:14:00Z',returncode:0,passed_criteria:6,total_criteria:6},
    {action:'finish',status:'passed',at:'2026-09-23T13:15:30Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'start',status:'in_progress',at:'2026-09-23T14:20:00Z',returncode:0,passed_criteria:0,total_criteria:0},
  ];
  const running=task({status:'in_progress',history});
  app.applyState(state([running],{summary:{total:1,passed:0,pending:0,in_progress:1,failed:0,error:0}}));
  assert.equal(doc.getElementById('duration-history').hidden,false);
  assert.equal(doc.getElementById('duration-history-list').children.length,1);
  const item=doc.getElementById('duration-history-list').children[0];
  assert.match(item.children[0].textContent,/00:15:30/);
  assert.match(item.children[0].textContent,/Aprovada/);
  assert.equal(doc.getElementById('stopwatch-state').textContent,'Em andamento');
  app.applyState(state([task()],{summary:{total:1,passed:0,pending:1,in_progress:0,failed:0,error:0}}));
  assert.equal(doc.getElementById('duration-history').hidden,true);
});

test('completed duration history renders real failure reasons without HTML interpretation', () => {
  const {doc,app}=setup();
  const history=[
    {action:'start',status:'in_progress',at:'2026-09-23T14:00:00Z',returncode:0,passed_criteria:0,total_criteria:0},
    {action:'grade',status:'failed',at:'2026-09-23T14:08:00Z',returncode:1,passed_criteria:2,total_criteria:6,failure_reasons:['porta 82 não liberada','<b>file1</b> ainda incorreto']},
    {action:'finish',status:'failed',at:'2026-09-23T14:10:00Z',returncode:0,passed_criteria:2,total_criteria:6,failure_reasons:[]},
  ];
  app.applyState(state([task({status:'failed',history})],{summary:{total:1,passed:0,pending:0,in_progress:0,failed:1,error:0}}));
  const item=doc.getElementById('duration-history-list').children[0];
  assert.equal(item.children.length,3);
  assert.equal(item.children[2].children[0].textContent,'Pendente: porta 82 não liberada');
  assert.equal(item.children[2].children[1].textContent,'Pendente: <b>file1</b> ainda incorreto');
});

test('polling reads only GET /api/state and retains clearly stale data on network or schema errors', async () => {
  const {doc,app,env}=setup();const calls=[];
  env.fetch=async(url,options)=>{calls.push({url,options});return {ok:true,json:async()=>state()};};
  await app.poll();
  assert.equal(calls[0].url,'/api/state');assert.equal(calls[0].options.method,'GET');
  assert.match(doc.getElementById('last-fetched').textContent,/Última consulta/);
  assert.match(doc.getElementById('updated-at').textContent,/sem registro/);
  env.fetch=async()=>{throw new Error('offline');};
  await app.poll();
  assert.equal(doc.getElementById('connection-error').hidden,false);
  assert.match(doc.getElementById('connection-error').textContent,/desatualizados/);
  assert.equal(doc.getElementById('task-title').textContent,'Usuários');
  env.fetch=async()=>({ok:true,json:async()=>({tasks:[]})});
  await app.poll();assert.match(doc.getElementById('connection-error').textContent,/inválida/);
  env.fetch=async()=>({ok:true,json:async()=>state()});
  await app.poll();assert.equal(doc.getElementById('connection-error').hidden,true);
  assert.equal(doc.getElementById('connection-label').textContent,'Monitorando');
  const timers=[];env.setTimeout=(fn,delay)=>{timers.push({fn,delay});return timers.length;};env.clearTimeout=()=>{};
  await app.start();assert.ok(timers.some(t=>t.delay===2000),'refresh schedules every 2 seconds');assert.ok(timers.some(t=>t.delay===1000),'stopwatch schedules every second');app.stop();
  const cold=setup();cold.env.fetch=async()=>({ok:false,status:503});await cold.app.poll();
  assert.match(cold.doc.getElementById('empty-state').textContent,/Não foi possível/);
});
test('copy works with secure clipboard, HTTP fallback, and explicit manual copy without false success', async () => {
  const {doc,app,env}=setup();let copied=null;
  env.navigator.clipboard={writeText:async value=>{copied=value;}};
  assert.equal(await app.copyText('lab grade users'),'clipboard');assert.equal(copied,'lab grade users');
  const focus=doc.getElementById('next-task');focus.focus();delete env.navigator.clipboard;
  assert.equal(await app.copyText('lab start users'),'legacy');assert.equal(doc.activeElement,focus);
  doc.execCommand=()=>false;
  assert.equal(await app.copyText('lab finish users'),'manual');
  assert.equal(doc.getElementById('manual-copy').hidden,false);
  assert.equal(doc.getElementById('manual-copy-input').value,'lab finish users');
  assert.match(doc.getElementById('announcer').textContent,/Cópia automática indisponível/);
  doc.getElementById('close-copy').listeners.click();assert.equal(doc.getElementById('manual-copy').hidden,true);
  assert.match(source(), /typeof document !== 'undefined'/);
  assert.match(source(), /dashboard\.start\(\)/);
});
test('PT-BR monitor has accessible landmarks and honest initial state', () => {
  const html=source();
  assert.match(html, /<html lang="pt-BR">/);
  for (const text of ['RHCSA · Laboratório','Simulado do vídeo · 24 tarefas + prova completa','Ainda não avaliada','Próxima pendente','Tempo da tentativa','ssh student@192.168.56.10']) assert.ok(html.includes(text),text);
  assert.match(html, /<main\b/);
  assert.match(html, /aria-live="polite"/);
  assert.match(html, /@media[^}]*max-width:\s*\d+px/);
  assert.doesNotMatch(html, /https?:\/\/[^"']+\.(?:js|css)["']/);
});

test('full exam countdown is visual only: remaining, overtime and finished states', () => {
  const {examCountdown} = helpers();
  const plain = value => JSON.parse(JSON.stringify(value));
  const limit = 180 * 60000;
  assert.deepEqual(plain(examCountdown({state:'waiting',elapsedMs:0},limit)),{state:'waiting',remainingMs:limit,overtimeMs:0,elapsedMs:0});
  assert.deepEqual(plain(examCountdown({state:'running',elapsedMs:3600000},limit)),{state:'running',remainingMs:7200000,overtimeMs:0,elapsedMs:3600000});
  assert.deepEqual(plain(examCountdown({state:'running',elapsedMs:limit+60000},limit)),{state:'overtime',remainingMs:0,overtimeMs:60000,elapsedMs:limit+60000});
  assert.equal(examCountdown({state:'finished',elapsedMs:limit+60000},limit).state,'finished','finished exam is never shown as overtime');
});

test('AI review markdown renders as DOM nodes only, never as HTML', () => {
  const {renderMarkdown} = helpers();
  const doc=dom();
  const md='## Veredito\nPassou em **12 min**.\n\n- usou `nmcli`\n- <img src=x onerror=alert(1)>\n1. um\n2. dois\n```\nsystemctl enable --now httpd\n<script>x</script>\n```';
  const out=renderMarkdown(doc,md);
  assert.deepEqual([...out.map(n=>n.tagName)],['h4','p','ul','ol','pre']);
  assert.equal(out[0].children[0].textContent,'Veredito');
  assert.deepEqual([...out[1].children.map(n=>n.tagName||'#text')],['#text','strong','#text']);
  assert.equal(out[1].children[1].textContent,'12 min');
  assert.equal(out[2].children.length,2);
  assert.equal(out[2].children[0].children[1].tagName,'code');
  assert.equal(out[2].children[1].children[0].textContent,'<img src=x onerror=alert(1)>','raw HTML stays text');
  assert.equal(out[3].children.length,2);
  assert.equal(out[4].children[0].textContent,'systemctl enable --now httpd\n<script>x</script>');
  assert.ok(!('innerHTML' in out[4].children[0]));
});

test('API contract accepts optional AI review and rejects malformed review', () => {
  const {validateState} = helpers();
  for (const review of [null,undefined,{state:'running',at:'2026-09-27T10:00:00Z'},{state:'done',at:null,markdown:'## Veredito'},{state:'error',at:'2026-09-27T10:00:00Z',error:'timeout'}]) {
    assert.doesNotThrow(()=>validateState(state([task({review})])));
  }
  for (const review of ['texto',{state:'pronto'},{state:'done',markdown:5},{state:'error',error:{}},{state:'done',at:7}]) {
    assert.throws(()=>validateState(state([task({review})])), /inválid/i);
  }
});

test('review block shows running, done and error states for the selected task', () => {
  const {doc,app} = setup();
  app.applyState(state([task({review:{state:'running',at:'2026-09-27T10:00:00Z'}})]));
  assert.equal(doc.getElementById('review-state').dataset.state,'running');
  assert.equal(doc.getElementById('review-empty').hidden,false);
  app.applyState(state([task({review:{state:'done',at:'2026-09-27T10:02:00Z',markdown:'## Veredito\nOk'}})]));
  assert.equal(doc.getElementById('review-state').dataset.state,'done');
  assert.equal(doc.getElementById('review-empty').hidden,true);
  assert.equal(doc.getElementById('review-body').children[0].tagName,'h4');
  app.applyState(state([task({review:{state:'error',at:'2026-09-27T10:02:00Z',error:'claude falhou'}})]));
  assert.match(doc.getElementById('review-empty').textContent,/claude falhou/);
  assert.equal(doc.getElementById('review-body').children.length,0);
});

function dynExam(overrides={}) {
  return {id:'dyn-20261004T210000Z',state:'open',seed:42,started_at:'2026-10-04T21:00:00Z',count:2,minimum:1,pass_mark:2,
    domains:[{n:1,name:'Software Management',quota:1},{n:4,name:'Storage',quota:1}],
    questions:[
      {q:1,id:'examsim-flatpak',kind:'legacy',title:'Flatpak',domain:1,domain_name:'Software Management',category:'flatpak',host:'servera',console:false,statement:'Adicione o remote examrepo. <img src=x onerror=alert(1)>'},
      {q:2,id:'examsim-swap',kind:'legacy',title:'Swap',domain:4,domain_name:'Storage',category:'swap',host:'serverb',console:true,statement:'Crie a swap.'}],
    ...overrides};
}
function dynTask(overrides={}) {
  return task({id:'examsim-dinamico',number:0,title:'Exame dinâmico',host:'workstation',hosts:['workstation'],solve_method:'console',solve_command:'',dynamic:true,exam_limit_minutes:180,...overrides});
}
test('dynamic exam payload is optional and a malformed one never breaks the dashboard', () => {
  const {validateState} = helpers();
  assert.equal(validateState(state([dynTask()])).dynamic_exam,undefined,'older APIs have no dynamic_exam');
  assert.equal(validateState(state([dynTask()],{dynamic_exam:null})).dynamic_exam,null);
  assert.equal(validateState(state([dynTask()],{dynamic_exam:dynExam()})).dynamic_exam.questions.length,2);
  const hostile=[{state:'hacked'},dynExam({seed:-1}),dynExam({questions:'x'}),dynExam({questions:[{q:1}]}),dynExam({id:'x'.repeat(65)}),
    dynExam({questions:[{...dynExam().questions[0],statement:'x'.repeat(4001)}]}),dynExam({domains:[{n:1,name:1,quota:1}]}),'texto',7];
  for (const bad of hostile) assert.equal(validateState(state([dynTask()],{dynamic_exam:bad})).dynamic_exam,null,JSON.stringify(bad).slice(0,60));
});
test('dynamic panel is only shown for the dynamic exam and lists the drawn questions as text', () => {
  const plain=setup('examsim-dinamico');
  plain.app.applyState(state([dynTask(),task()],{dynamic_exam:dynExam()}));
  const {doc}=plain;
  assert.equal(doc.getElementById('dynamic-section').hidden,false);
  assert.match(doc.getElementById('task-number').textContent,/Exame dinâmico/);
  assert.equal(doc.getElementById('dynamic-state').textContent,'Em andamento');
  assert.match(doc.getElementById('dynamic-sub').textContent,/2 questões .* seed 42/);
  assert.equal(doc.getElementById('dynamic-domains').children.length,2);
  assert.equal(doc.getElementById('dynamic-questions').children.length,2);
  assert.equal(doc.getElementById('dynamic-empty').hidden,true);
  const body=doc.getElementById('dynamic-questions').children[0].children[0].children[1];
  assert.equal(body.children[0].textContent,'Adicione o remote examrepo. <img src=x onerror=alert(1)>','statement is set as text, never HTML');
  const other=setup('users');
  other.app.applyState(state([dynTask(),task()],{dynamic_exam:dynExam()}));
  assert.equal(other.doc.getElementById('dynamic-section').hidden,true,'ordinary tasks have no dynamic panel');
});
test('dynamic panel without a published exam says so honestly', () => {
  const {doc,app}=setup('examsim-dinamico');
  app.applyState(state([dynTask()],{dynamic_exam:null}));
  assert.equal(doc.getElementById('dynamic-section').hidden,false);
  assert.equal(doc.getElementById('dynamic-empty').hidden,false);
  assert.equal(doc.getElementById('dynamic-state').textContent,'Sem prova');
  assert.equal(doc.getElementById('dynamic-questions').children.length,0);
});
test('closed dynamic exam shows score, per-domain result and per-question outcome', () => {
  const {doc,app}=setup('examsim-dinamico');
  const exam=dynExam({state:'closed',finished_at:'2026-10-04T22:00:00Z',
    score:{passed:1,total:2,pass_mark:2,percent:50,approved:false},by_domain:{'1':{passed:1,total:1},'4':{passed:0,total:1}}});
  exam.questions[0]={...exam.questions[0],ok:true,pending:''};
  exam.questions[1]={...exam.questions[1],ok:false,pending:'swap nao ativa'};
  app.applyState(state([dynTask()],{dynamic_exam:exam}));
  assert.equal(doc.getElementById('dynamic-state').textContent,'Corrigida');
  assert.equal(doc.getElementById('dynamic-state').dataset.status,'failed');
  assert.match(doc.getElementById('dynamic-sub').textContent,/nota 1\/2 \(50%\) · referência 2/);
  const domains=doc.getElementById('dynamic-domains').children;
  assert.equal(domains[0].dataset.state,'ok');
  assert.equal(domains[1].dataset.state,'partial');
  const items=doc.getElementById('dynamic-questions').children;
  assert.equal(items[0].dataset.ok,'true');
  assert.equal(items[1].dataset.ok,'false');
  assert.equal(items[1].children[0].children[1].children[1].textContent,'Pendente: swap nao ativa');
});
test('the "done" tick persists per exam in the browser and survives storage failures', () => {
  const ctx=setup('examsim-dinamico');
  ctx.app.applyState(state([dynTask()],{dynamic_exam:dynExam()}));
  const tick=(i)=>{const body=ctx.doc.getElementById('dynamic-questions').children[i].children[0].children[1];const label=body.children[body.children.length-1];return label.children[0];};
  tick(1).checked=true;tick(1).listeners.change();
  assert.equal(ctx.stored.get('rhcsa.dynDone.dyn-20261004T210000Z'),'[2]');
  tick(0).checked=true;tick(0).listeners.change();
  assert.deepEqual(JSON.parse(ctx.stored.get('rhcsa.dynDone.dyn-20261004T210000Z')).sort(),[1,2]);
  tick(1).checked=false;tick(1).listeners.change();
  assert.equal(ctx.stored.get('rhcsa.dynDone.dyn-20261004T210000Z'),'[1]');
  ctx.app.applyState(state([dynTask()],{dynamic_exam:dynExam({seed:43})}));
  assert.equal(tick(0).checked,true,'tick restored after a re-render');
  assert.equal(tick(1).checked,false);
  const broken=setup('examsim-dinamico');
  broken.env.storage.getItem=()=>{throw new Error('blocked');};broken.env.storage.setItem=()=>{throw new Error('blocked');};
  assert.doesNotThrow(()=>broken.app.applyState(state([dynTask()],{dynamic_exam:dynExam()})));
});
