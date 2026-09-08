const token = location.hash.slice(1) || sessionStorage.getItem('rallytrip-access') || '';
if (token) sessionStorage.setItem('rallytrip-access', token);
history.replaceState(null, '', location.pathname);
const status = document.querySelector('#status'), screen = document.querySelector('#screen');
let ended = false, busy = false, imageURL;
async function api(path, body) {
  const response = await fetch(path, {method: body ? 'POST' : 'GET', headers: {'Authorization': `Bearer ${token}`, ...(body ? {'Content-Type':'application/json'} : {})}, body: body ? JSON.stringify(body) : undefined, cache:'no-store'});
  if (!response.ok) { if ([401,410].includes(response.status)) ended = true; throw new Error((await response.json()).error || 'Verbindung unterbrochen'); }
  return response;
}
async function refresh() {
  if (ended) return;
  try {
    if (!busy) {
      const response = await api('/frame');
      const next = URL.createObjectURL(await response.blob());
      screen.src = next; if (imageURL) URL.revokeObjectURL(imageURL); imageURL = next;
      const remaining = (await (await api('/status')).json()).remaining;
      document.querySelector('#time').textContent = `Restzeit: ${Math.floor(remaining/60)}:${String(remaining%60).padStart(2,'0')} Minuten`;
      status.textContent = 'Verbunden · Tippen und Wischen möglich';
    }
  } catch(error) {status.textContent = error.message;}
  if (!ended) setTimeout(refresh, 1000);
}
async function command(body) {
  if (ended || busy) return;
  busy = true; status.textContent = 'Eingabe wird ausgeführt …';
  try {await api('/command', body); if (body.kind === 'stop') {ended = true; status.textContent = 'Testsitzung beendet.'; sessionStorage.removeItem('rallytrip-access');}}
  catch(error) {status.textContent = error.message;}
  finally {busy = false;}
}
let pointer;
screen.addEventListener('pointerdown', event => {screen.setPointerCapture(event.pointerId); pointer = {x:event.clientX,y:event.clientY};});
screen.addEventListener('pointerup', event => {
  if (!pointer) return;
  const dx = event.clientX-pointer.x, dy = event.clientY-pointer.y, rect = screen.getBoundingClientRect();
  if (Math.hypot(dx,dy)>25) command({kind:'swipe',direction:Math.abs(dx)>Math.abs(dy)?(dx>0?'right':'left'):(dy>0?'down':'up')});
  else command({kind:'tap',x:Math.max(0,Math.min(1,(event.clientX-rect.left)/rect.width)),y:Math.max(0,Math.min(1,(event.clientY-rect.top)/rect.height))});
  pointer = null;
});
screen.addEventListener('pointercancel',()=>{pointer=null;});
document.querySelectorAll('[data-direction]').forEach(button=>button.addEventListener('click',()=>command({kind:'swipe',direction:button.dataset.direction})));
document.querySelector('#restart').addEventListener('click',()=>command({kind:'restart'}));
document.querySelector('#stop').addEventListener('click',()=>command({kind:'stop'}));
document.querySelector('#typing').addEventListener('submit',event=>{event.preventDefault();command({kind:'text',text:document.querySelector('#text').value});});
refresh();
