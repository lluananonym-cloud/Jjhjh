// AFK-Bot: joint den Server, bleibt STAY_MINUTES online, bewegt sich ab und zu, verbindet neu bei Kick.
const mineflayer = require('mineflayer');

const HOST = process.env.MC_HOST || 'mythoscraft.mcsh.io';
const PORT = parseInt(process.env.MC_PORT || '25565', 10);
const NAME = process.env.BOT_NAME || 'MythosBot';
const PASS = process.env.AUTHME_PASSWORD || '';
const STAY = parseFloat(process.env.STAY_MINUTES || '25') * 60 * 1000;
const deadline = Date.now() + STAY;

let bot, moveTimer;
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);

function connect() {
  if (Date.now() > deadline) return finish();
  log(`Verbinde mit ${HOST}:${PORT} als ${NAME} ...`);
  bot = mineflayer.createBot({ host: HOST, port: PORT, username: NAME, auth: 'offline', hideErrors: true });

  bot.once('spawn', () => {
    log('Online.');
    if (PASS) {
      // AuthMe: erst registrieren versuchen, dann einloggen (eins davon schlägt still fehl)
      setTimeout(() => bot.chat(`/register ${PASS} ${PASS}`), 1500);
      setTimeout(() => bot.chat(`/login ${PASS}`), 3500);
    }
    moveTimer = setInterval(antiAfk, 45 * 1000);
  });

  bot.on('kicked', r => log('Gekickt:', typeof r === 'string' ? r : JSON.stringify(r)));
  bot.on('error', e => log('Fehler:', e.code || e.message));
  bot.on('end', () => {
    clearInterval(moveTimer);
    if (Date.now() < deadline) { log('Getrennt, neuer Versuch in 30 s'); setTimeout(connect, 30 * 1000); }
    else finish();
  });
}

function antiAfk() {
  if (!bot?.entity) return;
  bot.look(Math.random() * Math.PI * 2, 0, true);
  bot.setControlState('jump', true);
  setTimeout(() => bot.setControlState('jump', false), 400);
  bot.swingArm();
}

let done = false;
function finish() {
  if (done) return; done = true;
  log('Zeit abgelaufen, verlasse den Server.');
  try { bot?.quit('Bis gleich'); } catch {}
  setTimeout(() => process.exit(0), 2000);
}

setTimeout(finish, STAY);
connect();
