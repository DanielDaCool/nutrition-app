// Read-only dashboard: fetches the phone app's data export from a private
// GitHub gist (the sync target from Settings > PC dashboard) and charts it.
// No write-back to the gist or the app — this page only displays.

const TOKEN_KEY = 'nutritionDashboard.token';
const GIST_KEY = 'nutritionDashboard.gistId';
const FILE_NAME = 'nutrition-data.json';

const els = {
  setupPanel: document.getElementById('setupPanel'),
  dashboard: document.getElementById('dashboard'),
  tokenInput: document.getElementById('tokenInput'),
  gistInput: document.getElementById('gistInput'),
  setupError: document.getElementById('setupError'),
  loadError: document.getElementById('loadError'),
  asOf: document.getElementById('asOf'),
  todayStats: document.getElementById('todayStats'),
  workoutsBody: document.querySelector('#workoutsTable tbody'),
  noWorkouts: document.getElementById('noWorkouts'),
};

function dayKeyToday() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function lastNDayKeys(n) {
  const keys = [];
  const d = new Date();
  for (let i = n - 1; i >= 0; i--) {
    const day = new Date(d);
    day.setDate(d.getDate() - i);
    const pad = (v) => String(v).padStart(2, '0');
    keys.push(`${day.getFullYear()}-${pad(day.getMonth() + 1)}-${pad(day.getDate())}`);
  }
  return keys;
}

function getCreds() {
  return {
    token: localStorage.getItem(TOKEN_KEY) || '',
    gistId: localStorage.getItem(GIST_KEY) || '',
  };
}

function saveCreds(token, gistId) {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(GIST_KEY, gistId);
}

function forgetCreds() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(GIST_KEY);
}

async function fetchExport(token, gistId) {
  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
  };
  const res = await fetch(`https://api.github.com/gists/${encodeURIComponent(gistId)}`, { headers });
  if (!res.ok) {
    throw new Error(res.status === 404 ? 'Gist not found — check the id' : `GitHub error (${res.status})`);
  }
  const json = await res.json();
  const file = json.files && json.files[FILE_NAME];
  if (!file) throw new Error(`No "${FILE_NAME}" file in that gist`);
  let content = file.content;
  if (file.truncated) {
    const rawRes = await fetch(file.raw_url, { headers });
    if (!rawRes.ok) throw new Error(`Could not fetch full data (${rawRes.status})`);
    content = await rawRes.text();
  }
  return JSON.parse(content);
}

function tableRows(exportData, name) {
  return (exportData.tables && exportData.tables[name]) || [];
}

function currentTarget(targetHistory, today) {
  let best = null;
  for (const t of targetHistory) {
    if (t.effectiveFrom <= today && (!best || t.effectiveFrom > best.effectiveFrom)) {
      best = t;
    }
  }
  return best;
}

function sumByDay(entries, days, field) {
  const totals = Object.fromEntries(days.map((d) => [d, 0]));
  for (const e of entries) {
    if (e.dayKey in totals) totals[e.dayKey] += e[field] || 0;
  }
  return days.map((d) => totals[d]);
}

let weightChart, calorieChart, stepsChart;

function renderWeight(weighIns, days) {
  const byDay = Object.fromEntries(weighIns.map((w) => [w.dayKey, w.weightKg]));
  const points = days.map((d) => byDay[d] ?? null);
  weightChart?.destroy();
  weightChart = new Chart(document.getElementById('weightChart'), {
    type: 'line',
    data: {
      labels: days,
      datasets: [{ label: 'Weight (kg)', data: points, spanGaps: true, borderColor: '#8C9EFF', tension: 0.2 }],
    },
    options: chartOptions(),
  });
}

function renderCalories(foodLog, target, days) {
  const kcalByDay = sumByDay(foodLog, days, 'kcal');
  calorieChart?.destroy();
  calorieChart = new Chart(document.getElementById('calorieChart'), {
    type: 'bar',
    data: {
      labels: days,
      datasets: [
        { label: 'Kcal eaten', data: kcalByDay, backgroundColor: '#8C9EFF' },
        ...(target
          ? [{
              label: 'Target',
              data: days.map(() => target.kcal),
              type: 'line',
              borderColor: '#FF9E7A',
              pointRadius: 0,
              borderDash: [6, 4],
            }]
          : []),
      ],
    },
    options: chartOptions(),
  });

  const today = dayKeyToday();
  const todayEntries = foodLog.filter((e) => e.dayKey === today);
  const totals = { kcal: 0, proteinG: 0, fatG: 0, carbsG: 0 };
  for (const e of todayEntries) {
    totals.kcal += e.kcal || 0;
    totals.proteinG += e.proteinG || 0;
    totals.fatG += e.fatG || 0;
    totals.carbsG += e.carbsG || 0;
  }
  const stat = (label, value, goal) => {
    const over = goal != null && value > goal;
    return `<div class="stat${over ? ' over' : ''}"><div class="value">${Math.round(value)}${goal != null ? ` / ${Math.round(goal)}` : ''}</div><div class="label">${label}</div></div>`;
  };
  els.todayStats.innerHTML = [
    stat('Kcal today', totals.kcal, target?.kcal),
    stat('Protein g', totals.proteinG, target?.proteinG),
    stat('Fat g', totals.fatG, target?.fatG),
    stat('Carbs g', totals.carbsG, target?.carbsG),
  ].join('');
}

function renderSteps(dailySteps, days) {
  const byDay = Object.fromEntries(dailySteps.map((s) => [s.dayKey, s.steps]));
  const points = days.map((d) => byDay[d] ?? 0);
  stepsChart?.destroy();
  stepsChart = new Chart(document.getElementById('stepsChart'), {
    type: 'bar',
    data: { labels: days, datasets: [{ label: 'Steps', data: points, backgroundColor: '#8C9EFF' }] },
    options: chartOptions(),
  });
}

function formatDuration(startIso, endIso) {
  const ms = new Date(endIso) - new Date(startIso);
  const mins = Math.round(ms / 60000);
  if (mins < 60) return `${mins} min`;
  return `${Math.floor(mins / 60)}h ${mins % 60}m`;
}

function renderWorkouts(workouts) {
  const sorted = [...workouts].sort((a, b) => (a.startTime < b.startTime ? 1 : -1)).slice(0, 20);
  els.workoutsBody.innerHTML = sorted
    .map(
      (w) =>
        `<tr><td>${w.dayKey}</td><td>${escapeHtml(w.title)}</td><td>${formatDuration(w.startTime, w.endTime)}</td><td>${w.kcal ? Math.round(w.kcal) : '—'}</td></tr>`,
    )
    .join('');
  els.noWorkouts.classList.toggle('hidden', sorted.length > 0);
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function chartOptions() {
  return {
    responsive: true,
    scales: {
      x: { ticks: { color: '#A0A4B8', maxTicksLimit: 8 }, grid: { color: '#323647' } },
      y: { ticks: { color: '#A0A4B8' }, grid: { color: '#323647' } },
    },
    plugins: { legend: { labels: { color: '#E7E8F0' } } },
  };
}

async function loadAndRender() {
  const { token, gistId } = getCreds();
  els.loadError.classList.add('hidden');
  try {
    const data = await fetchExport(token, gistId);
    const days = lastNDayKeys(30);
    const target = currentTarget(tableRows(data, 'TargetHistory'), dayKeyToday());
    renderWeight(tableRows(data, 'WeighIns'), days);
    renderCalories(tableRows(data, 'FoodLogEntries'), target, days);
    renderSteps(tableRows(data, 'DailySteps'), days);
    renderWorkouts(tableRows(data, 'Workouts'));
    els.asOf.textContent = `Phone data as of ${new Date(data.exportedAt).toLocaleString()}`;
    els.dashboard.classList.remove('hidden');
    els.setupPanel.classList.add('hidden');
  } catch (e) {
    els.loadError.textContent = e.message || String(e);
    els.loadError.classList.remove('hidden');
    els.dashboard.classList.add('hidden');
    els.setupPanel.classList.remove('hidden');
  }
}

document.getElementById('settingsBtn').addEventListener('click', () => {
  const { token, gistId } = getCreds();
  els.tokenInput.value = token;
  els.gistInput.value = gistId;
  els.setupPanel.classList.toggle('hidden');
});

document.getElementById('saveSetupBtn').addEventListener('click', async () => {
  const token = els.tokenInput.value.trim();
  const gistId = els.gistInput.value.trim();
  els.setupError.textContent = '';
  if (!token || !gistId) {
    els.setupError.textContent = 'Both fields are required';
    return;
  }
  saveCreds(token, gistId);
  await loadAndRender();
  if (!els.dashboard.classList.contains('hidden')) return;
  els.setupError.textContent = els.loadError.textContent;
});

document.getElementById('forgetBtn').addEventListener('click', () => {
  forgetCreds();
  els.tokenInput.value = '';
  els.gistInput.value = '';
  els.dashboard.classList.add('hidden');
  els.setupPanel.classList.remove('hidden');
});

(function init() {
  const { token, gistId } = getCreds();
  if (token && gistId) {
    loadAndRender();
  } else {
    els.setupPanel.classList.remove('hidden');
  }
})();
