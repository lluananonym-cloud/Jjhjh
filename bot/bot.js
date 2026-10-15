// AFK-Bot: bleibt online, springt am Spawn, /spawn alle 10 Min, schreibt ab und zu etwas in den Chat.
const mineflayer = require('mineflayer');

const HOST = process.env.MC_HOST;
const PORT = parseInt(process.env.MC_PORT || '25565', 10);
const NAME = process.env.BOT_NAME || 'MythosBot';
const PASS = process.env.AUTHME_PASSWORD || '';
const STAY = parseFloat(process.env.STAY_MINUTES || '350') * 60 * 1000;
const deadline = Date.now() + STAY;

const MESSAGES = [
  'Welcome to Mythoscraft!',
  'Have fun and play fair :)',
  'Need help? Just ask in chat.',
  'Don\'t forget to check out MinePro641 on YouTube!',
  'Nice weather at spawn today.',
  'Remember to sleep at night, creepers are out there.',
  'Build something cool today!',
  'Who wants to go mining?',
  'Stay hydrated, gamers.',
  'GG everyone!'
];

if (!HOST) { console.error('MC_HOST fehlt'); process.exit(1); }

let bot, timers = [];
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const clearTimers = () => { timers.forEach(clearInterval); timers.forEach(clearTimeout); timers = []; };

function connect() {
  if (Date.now() > deadline) return finish();
  log(`Verbinde mit ${HOST}:${PORT} als ${NAME} ...`);
  bot = mineflayer.createBot({ host: HOST, port: PORT, username: NAME, auth: 'offline', hideErrors: true });

  bot.once('spawn', () => {
    log('Online.');
    if (PASS) {
      timers.push(setTimeout(() => bot.chat(`/register ${PASS} ${PASS}`), 1500));
      timers.push(setTimeout(() => bot.chat(`/login ${PASS}`), 3500));
    }
    timers.push(setTimeout(goSpawn, 6000));
    timers.push(setInterval(goSpawn, 10 * 60 * 1000));
    timers.push(setInterval(jump, 3000));
    scheduleChat();
  });

  bot.on('kicked', r => log('Gekickt:', typeof r === 'string' ? r : JSON.stringify(r)));
  bot.on('error', e => log('Fehler:', e.code || e.message));
  bot.on('end', () => {
    clearTimers();
    if (Date.now() < deadline) { log('Getrennt, neuer Versuch in 30 s'); setTimeout(connect, 30 * 1000); }
    else finish();
  });
}

function goSpawn() { if (bot?.entity) { bot.chat('/spawn'); log('/spawn'); } }

function jump() {
  if (!bot?.entity) return;
  bot.setControlState('jump', true);
  setTimeout(() => bot?.setControlState('jump', false), 300);
  if (Math.random() < 0.3) bot.look(Math.random() * Math.PI * 2, 0, true);
}

function scheduleChat() {
  const wait = (15 + Math.random() * 15) * 60 * 1000; // alle 15–30 Minuten
  timers.push(setTimeout(() => {
    if (bot?.entity) { const m = MESSAGES[Math.floor(Math.random() * MESSAGES.length)]; bot.chat(m); log('Chat:', m); }
    scheduleChat();
  }, wait));
}

let done = false;
function finish() {
  if (done) return; done = true;
  log('Laufzeit vorbei, verlasse den Server.');
  try { bot?.quit(); } catch {}
  setTimeout(() => process.exit(0), 2000);
}

setTimeout(finish, STAY);
connect();
