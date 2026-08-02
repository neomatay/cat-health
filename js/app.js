// ============================================================
// 猫咪健康 PWA - Vue 3 应用逻辑
// ============================================================
const { createApp, ref, reactive, computed, onMounted, watch, nextTick } = Vue;

// ---- 工具函数 ----
function pad(n) { return String(n).padStart(2, '0'); }
function todayStr() {
  var d = new Date(); return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
}
function fmtDate(s) {
  if (!s) return '';
  var p = String(s).split('-');
  return p[1] + '月' + p[2] + '日';
}
function fmtDateTime(s) {
  if (!s) return '';
  var d = new Date(s.replace(' ', 'T'));
  return pad(d.getMonth() + 1) + '月' + pad(d.getDate()) + '日 ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}
function nowHMS() {
  var d = new Date(); return pad(d.getHours()) + ':' + pad(d.getMinutes());
}

createApp({
  setup() {
    // ========== 全局状态 ==========
    var activeTab = ref('today');
    var showCatMenu = ref(false);
    var loading = ref(false);
    var toastMsg = ref('');
    var toastTimer = null;
    var cats = ref([]);
    var currentCatId = ref(null);
    var weights = ref([]);
    var temps = ref([]);
    var plans = ref([]);
    var allLogs = ref([]); // 当前猫咪所有用药打卡记录

    // 趋势
    var trendMetric = ref('weight'); // weight | temp
    var trendRange = ref('7'); // 7 | 30 | all
    var chartRef = ref(null);
    var chartInstance = null;

    // ========== 弹层状态 ==========
    var modal = reactive({
      addCat: false, editCat: false,
      addWeight: false, addTemp: false, quickRecord: false, reminders: false,
      addPlan: false, editPlan: false,
      joinFamily: false, importData: false
    });
    var catForm = reactive({ name: '', breed: '', birthday: '', avatar: '' });
    var editingCatId = ref(null);
    var weightForm = reactive({ id: null, cat_id: null, date: todayStr(), kg: '', note: '' });
    var tempForm = reactive({ id: null, cat_id: null, date: todayStr(), celsius: '', note: '' });
    var planForm = reactive({
      cat_id: null, drug: '', dose_amount: '', dose_unit: '片', remind_times: ['08:00'],
      freq_type: 'daily', weekdays: [], interval_days: 2, remind_before: 0,
      start_date: todayStr(), end_date: '', is_long_term: true, note: ''
    });
    var editingPlanId = ref(null);
    var joinCode = ref('');
    var importText = ref('');
    var errors = reactive({});

    // ========== lucide 风格内联线性图标 ==========
    var ICON_PATHS = {
      home: '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/>',
      chart: '<path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="m19 9-5 5-4-4-3 3"/>',
      pill: '<path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z"/><path d="m8.5 8.5 7 7"/>',
      users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
      weight: '<circle cx="12" cy="5" r="3"/><path d="M6.5 8h11a2 2 0 0 1 1.9 1.4l2.3 8.1A2 2 0 0 1 19.8 21H4.2a2 2 0 0 1-1.9-2.5l2.3-8.1A2 2 0 0 1 6.5 8Z"/>',
      thermometer: '<path d="M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z"/>',
      plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
      chevron: '<path d="m9 18 6-6-6-6"/>',
      check: '<path d="M20 6 9 17l-5-5"/>',
      x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
      bell: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
      more: '<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
      share: '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.6 13.5 6.8 4M15.4 6.5l-6.8 4"/>',
      shield: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
      heart: '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/><path d="M3.2 12h4.3l.5-2 2 4.5 2-7 1.5 3.5h4.3"/>',
      feather: '<path d="M12.67 19a2 2 0 0 0 1.42-.59l6.36-6.36a4.95 4.95 0 0 0-7-7l-8.5 8.5a4.95 4.95 0 0 0 7 7Z"/><path d="M16 8 2 22"/><path d="M17.5 15H9"/>',
      paw: '<circle cx="11" cy="4" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="4" cy="8" r="2"/><circle cx="20" cy="16" r="2"/><path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.05Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z"/>',
      activity: '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>',
      calendar: '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/><path d="M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01M16 18h.01"/>',
      copy: '<rect x="8" y="8" width="14" height="14" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
      download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/>',
      upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m17 8-5-5-5 5"/><path d="M12 3v12"/>',
      edit: '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>'
    };
    function iconSvg(name, size) {
      var s = size || 20;
      return '<svg width="' + s + '" height="' + s + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + (ICON_PATHS[name] || '') + '</svg>';
    }

    // ========== 计算属性 ==========
    var currentCat = computed(function () {
      return cats.value.find(function (c) { return c.id === currentCatId.value; }) || null;
    });
    var hasCats = computed(function () { return cats.value.length > 0; });

    // ========== 首页总览数据 ==========
    var greeting = computed(function () {
      var h = new Date().getHours();
      if (h < 6) return '夜深了'; if (h < 12) return '早上好';
      if (h < 18) return '下午好'; return '晚上好';
    });
    var todayLabel = computed(function () {
      var d = new Date();
      return (d.getMonth() + 1) + '月' + d.getDate() + '日 周' + WD_NAMES[d.getDay()];
    });
    function latestOf(arr) { return arr.value.length ? arr.value[arr.value.length - 1] : null; }
    var latestWeight = computed(function () { return latestOf(weights); });
    var latestTemp = computed(function () { return latestOf(temps); });
    // 与上一条体重的差值文案
    var weightDelta = computed(function () {
      var n = weights.value.length;
      if (n < 2) return '暂无对比数据';
      var diff = parseFloat(weights.value[n - 1].kg) - parseFloat(weights.value[n - 2].kg);
      return '较上次 ' + (diff >= 0 ? '+' : '') + diff.toFixed(2) + ' kg';
    });
    var tempStatus = computed(function () {
      if (!latestTemp.value) return { text: '暂无数据', cls: '' };
      var c = parseFloat(latestTemp.value.celsius);
      if (c < 38.0) return { text: '偏低，注意保暖', cls: 'warm' };
      if (c > 39.2) return { text: '偏高，建议就医', cls: 'warm' };
      return { text: '处于正常范围', cls: 'ok' };
    });
    // 今日用药进度
    var doseDone = computed(function () { return todayTasks.value.filter(function (t) { return t.status === 'taken'; }).length; });
    var doseTotal = computed(function () { return todayTasks.value.length; });
    var nextDose = computed(function () {
      return todayTasks.value.find(function (t) { return t.status === 'pending' || t.status === 'overdue'; }) || null;
    });
    // 护理提示：最近 3 条体重极差超过 5% 时显示
    var careTip = computed(function () {
      var arr = weights.value.slice(-3);
      if (arr.length < 3) return '';
      var vals = arr.map(function (w) { return parseFloat(w.kg); });
      var min = Math.min.apply(null, vals), max = Math.max.apply(null, vals);
      if (min > 0 && (max - min) / min > 0.05) return '近期体重波动超过 5%，建议关注饮食与精神状态，必要时就医。';
      return '连续 3 天体重变化超过 5% 时，建议复查饮食与就诊计划。';
    });
    // 趋势页近期记录（当前指标最近 5 条，倒序，可点击编辑）
    var trendRecords = computed(function () {
      var isW = trendMetric.value === 'weight';
      var arr = (isW ? weights.value : temps.value).slice(-5).reverse();
      return arr.map(function (r) {
        return {
          type: isW ? 'weight' : 'temp', id: r.id, cat_id: r.cat_id, date: r.date,
          kg: r.kg, celsius: r.celsius, note: r.note,
          val: isW ? r.kg + ' kg' : r.celsius + ' °C'
        };
      });
    });
    // 猫咪年龄（x岁x个月 / x个月）
    function catAge(cat) {
      if (!cat || !cat.birthday) return '';
      var b = new Date(cat.birthday + 'T00:00:00'), now = new Date();
      var m = (now.getFullYear() - b.getFullYear()) * 12 + now.getMonth() - b.getMonth();
      if (now.getDate() < b.getDate()) m--;
      if (m < 0) return '';
      if (m < 12) return m + ' 个月';
      var y = Math.floor(m / 12), r = m % 12;
      return r ? y + ' 岁 ' + r + ' 个月' : y + ' 岁';
    }
    function editCurrentCat() { if (currentCat.value) openEditCat(currentCat.value); }
    // 任务实际提醒时间 = 用药时间 - 提前量（铃铛提醒中心用）
    function remindTimeOf(t) {
      var before = parseInt(t.plan.remind_before) || 0;
      if (!before) return t.time;
      var p = t.time.split(':');
      var mins = parseInt(p[0]) * 60 + parseInt(p[1]) - before;
      if (mins < 0) mins += 1440;
      return pad(Math.floor(mins / 60)) + ':' + pad(mins % 60);
    }
    // 进行中的计划（提醒中心-日历入口用）
    var activePlans = computed(function () {
      return planList.value.filter(function (item) { return item.ongoing; });
    });
    // FAB 快捷记录：选择体重或体温
    function openQuickRecord() {
      if (!currentCatId.value) { showToast('请先添加猫咪'); return; }
      modal.quickRecord = true;
    }
    function pickRecordType(t) {
      modal.quickRecord = false;
      if (t === 'weight') openAddWeight(); else openAddTemp();
    }

    // 剂量解析：把存量文本（"0.5 片"/"半片"/"250mg"）拆成 数字+单位，拆不出则留空待用户重填
    function parseDose(dose) {
      var r = { amount: '', unit: '片' };
      if (!dose) return r;
      var s = String(dose).trim().replace(/半/g, '0.5');
      var m = s.match(/^([\d.]+)\s*(毫克|mg|片|粒)$/i);
      if (m) {
        r.amount = m[1];
        r.unit = /毫克|mg/i.test(m[2]) ? '毫克' : m[2];
      }
      return r;
    }

    // ========== 用药频次 ==========
    // freq_type: daily 每天 | weekly 每周固定几(weekdays: 0=日 1=一...6=六) | interval 每N天(以start_date为第一次)
    var WD_NAMES = ['日', '一', '二', '三', '四', '五', '六'];
    var weekdayOptions = [
      { value: 1, label: '一' }, { value: 2, label: '二' }, { value: 3, label: '三' },
      { value: 4, label: '四' }, { value: 5, label: '五' }, { value: 6, label: '六' },
      { value: 0, label: '日' }
    ];
    function toggleWeekday(d) {
      var i = planForm.weekdays.indexOf(d);
      if (i >= 0) planForm.weekdays.splice(i, 1); else planForm.weekdays.push(d);
    }
    // 判断某天是否该服药
    function isDoseDay(plan, dateStr) {
      var ft = plan.freq_type || 'daily';
      if (ft === 'weekly') {
        var wd = new Date(dateStr + 'T00:00:00').getDay();
        return (plan.weekdays || []).indexOf(wd) >= 0;
      }
      if (ft === 'interval') {
        var n = parseInt(plan.interval_days) || 1;
        var start = new Date(plan.start_date + 'T00:00:00');
        var cur = new Date(dateStr + 'T00:00:00');
        var diff = Math.round((cur - start) / 86400000);
        return diff >= 0 && diff % n === 0;
      }
      return true; // daily
    }
    // 频次展示文案
    function freqText(plan) {
      var ft = plan.freq_type || 'daily';
      if (ft === 'weekly') {
        var days = (plan.weekdays || []).slice().sort(function (a, b) { return ((a + 6) % 7) - ((b + 6) % 7); });
        return '每周' + days.map(function (d) { return WD_NAMES[d]; }).join('、');
      }
      if (ft === 'interval') return '每' + (plan.interval_days || 1) + '天一次';
      return '每天';
    }

    // 今日用药任务
    var todayTasks = computed(function () {
      var today = todayStr();
      var now = new Date();
      var tasks = [];
      var catPlans = plans.value.filter(function (p) {
        return p.cat_id === currentCatId.value && p.active &&
          p.start_date <= today && (!p.end_date || p.end_date >= today) &&
          isDoseDay(p, today);
      });
      catPlans.forEach(function (plan) {
        (plan.remind_times || []).forEach(function (time) {
          var log = allLogs.value.find(function (l) {
            return l.plan_id === plan.id && l.date === today && l.scheduled_time === time;
          });
          var status = log ? log.status : 'pending';
          // 超 30 分钟未喂标红
          if (!log) {
            var parts = time.split(':');
            var scheduled = new Date();
            scheduled.setHours(parseInt(parts[0]), parseInt(parts[1]), 0, 0);
            if (now > new Date(scheduled.getTime() + 30 * 60000)) status = 'overdue';
          }
          tasks.push({ plan: plan, time: time, status: status, log: log });
        });
      });
      tasks.sort(function (a, b) { return a.time.localeCompare(b.time); });
      return tasks;
    });

    // 今日待办数（未喂 + 错过）
    var todayPending = computed(function () {
      return todayTasks.value.filter(function (t) { return t.status === 'pending' || t.status === 'overdue'; }).length;
    });

    // 最近 5 条记录（体重+体温合并，带原始字段供点击编辑）
    var recentRecords = computed(function () {
      var arr = [];
      weights.value.forEach(function (w) { arr.push({ type: 'weight', id: w.id, cat_id: w.cat_id, date: w.date, kg: w.kg, val: w.kg + ' kg', note: w.note }); });
      temps.value.forEach(function (t) { arr.push({ type: 'temp', id: t.id, cat_id: t.cat_id, date: t.date, celsius: t.celsius, val: t.celsius + ' °C', note: t.note }); });
      arr.sort(function (a, b) { return (b.date || '').localeCompare(a.date || ''); });
      return arr.slice(0, 5);
    });

    // 计划进度列表
    var planList = computed(function () {
      return plans.value.map(function (plan) {
        var logs = allLogs.value.filter(function (l) { return l.plan_id === plan.id; });
        var taken = logs.filter(function (l) { return l.status === 'taken'; }).length;
        var skipped = logs.filter(function (l) { return l.status === 'skipped'; }).length;
        var missed = logs.filter(function (l) { return l.status === 'missed'; }).length;
        var total = taken + skipped + missed;
        var rate = total > 0 ? Math.round(taken / total * 100) : 0;
        var ongoing = plan.active && (!plan.end_date || plan.end_date >= todayStr());
        return { plan: plan, taken: taken, skipped: skipped, missed: missed, total: total, rate: rate, ongoing: ongoing };
      });
    });

    // ========== Toast ==========
    function showToast(msg) {
      toastMsg.value = msg;
      if (toastTimer) clearTimeout(toastTimer);
      toastTimer = setTimeout(function () { toastMsg.value = ''; }, 2500);
    }

    // ========== 数据加载 ==========
    async function loadCats() {
      try { cats.value = await CatStore.getCats(); }
      catch (e) { console.error(e); showToast('加载猫咪失败'); }
    }

    async function loadCatData(catId) {
      if (!catId) { weights.value = []; temps.value = []; plans.value = []; allLogs.value = []; return; }
      loading.value = true;
      try {
        var results = await Promise.all([
          CatStore.getWeights(catId),
          CatStore.getTemps(catId),
          CatStore.getMedPlans(catId)
        ]);
        weights.value = results[0];
        temps.value = results[1];
        plans.value = results[2];
        // 加载所有计划的打卡记录
        var logsArr = [];
        for (var i = 0; i < plans.value.length; i++) {
          var logs = await CatStore.getMedLogs({ plan_id: plans.value[i].id });
          logsArr = logsArr.concat(logs);
        }
        allLogs.value = logsArr;
      } catch (e) { console.error(e); showToast('加载数据失败'); }
      finally { loading.value = false; }
    }

    async function switchCat(id) {
      currentCatId.value = id;
      await loadCatData(id);
      if (activeTab.value === 'trend') { await nextTick(); renderChart(); }
    }

    async function switchTab(tab) {
      activeTab.value = tab;
      if (tab === 'trend') { await nextTick(); renderChart(); }
    }

    // ========== 今日用药打卡 ==========
    async function markTaken(task) {
      try {
        await CatStore.upsertMedLog({
          plan_id: task.plan.id, cat_id: task.plan.cat_id, date: todayStr(),
          scheduled_time: task.time, status: 'taken', taken_at: new Date().toISOString()
        });
        await refreshLogs();
        showToast('已记录喂药');
      } catch (e) { console.error(e); showToast('记录失败'); }
    }

    async function markSkipped(task) {
      try {
        await CatStore.upsertMedLog({
          plan_id: task.plan.id, cat_id: task.plan.cat_id, date: todayStr(),
          scheduled_time: task.time, status: 'skipped', taken_at: null
        });
        await refreshLogs();
        showToast('已跳过');
      } catch (e) { console.error(e); showToast('操作失败'); }
    }

    async function refreshLogs() {
      var logsArr = [];
      for (var i = 0; i < plans.value.length; i++) {
        var logs = await CatStore.getMedLogs({ plan_id: plans.value[i].id });
        logsArr = logsArr.concat(logs);
      }
      allLogs.value = logsArr;
    }

    // ========== 快速记录：体重/体温 ==========
    function openAddWeight() {
      if (!currentCatId.value) return;
      weightForm.id = null;
      weightForm.cat_id = currentCatId.value;
      weightForm.date = todayStr();
      weightForm.kg = ''; weightForm.note = '';
      errors.kg = '';
      modal.addWeight = true;
    }
    function openAddTemp() {
      if (!currentCatId.value) return;
      tempForm.id = null;
      tempForm.cat_id = currentCatId.value;
      tempForm.date = todayStr();
      tempForm.celsius = ''; tempForm.note = '';
      errors.celsius = '';
      modal.addTemp = true;
    }

    // 点击最近记录 → 编辑该条（可改数值/日期/备注，可删除）
    function openEditRecord(r) {
      if (r.type === 'weight') {
        weightForm.id = r.id; weightForm.cat_id = r.cat_id; weightForm.date = r.date;
        weightForm.kg = String(r.kg); weightForm.note = r.note || '';
        errors.kg = ''; modal.addWeight = true;
      } else {
        tempForm.id = r.id; tempForm.cat_id = r.cat_id; tempForm.date = r.date;
        tempForm.celsius = String(r.celsius); tempForm.note = r.note || '';
        errors.celsius = ''; modal.addTemp = true;
      }
    }

    async function deleteWeightRecord() {
      if (!weightForm.id) return;
      if (!confirm('确定删除这条体重记录吗？')) return;
      try {
        await CatStore.deleteWeight(weightForm.id);
        weights.value = await CatStore.getWeights(currentCatId.value);
        modal.addWeight = false; showToast('已删除');
        if (activeTab.value === 'trend' && trendMetric.value === 'weight') renderChart();
      } catch (e) { console.error(e); showToast('删除失败'); }
    }
    async function deleteTempRecord() {
      if (!tempForm.id) return;
      if (!confirm('确定删除这条体温记录吗？')) return;
      try {
        await CatStore.deleteTemp(tempForm.id);
        temps.value = await CatStore.getTemps(currentCatId.value);
        modal.addTemp = false; showToast('已删除');
        if (activeTab.value === 'trend' && trendMetric.value === 'temp') renderChart();
      } catch (e) { console.error(e); showToast('删除失败'); }
    }

    async function saveWeight() {
      var kg = parseFloat(weightForm.kg);
      if (isNaN(kg) || kg < 0.1 || kg > 20) { errors.kg = '请输入 0.1-20 kg'; return; }
      try {
        if (weightForm.id) {
          await CatStore.updateWeight(weightForm.id, { date: weightForm.date, kg: kg, note: weightForm.note });
          showToast('体重已更新');
        } else {
          await CatStore.addWeight({ cat_id: weightForm.cat_id, date: weightForm.date, kg: kg, note: weightForm.note });
          showToast('体重已记录');
        }
        if (weightForm.cat_id === currentCatId.value) weights.value = await CatStore.getWeights(currentCatId.value);
        modal.addWeight = false;
        if (activeTab.value === 'trend' && trendMetric.value === 'weight') renderChart();
      } catch (e) { console.error(e); showToast('保存失败'); }
    }

    async function saveTemp() {
      var c = parseFloat(tempForm.celsius);
      if (isNaN(c) || c < 35 || c > 42) { errors.celsius = '请输入 35-42 °C'; return; }
      try {
        if (tempForm.id) {
          await CatStore.updateTemp(tempForm.id, { date: tempForm.date, celsius: c, note: tempForm.note });
          showToast('体温已更新');
        } else {
          await CatStore.addTemp({ cat_id: tempForm.cat_id, date: tempForm.date, celsius: c, note: tempForm.note });
          showToast('体温已记录');
        }
        if (tempForm.cat_id === currentCatId.value) temps.value = await CatStore.getTemps(currentCatId.value);
        modal.addTemp = false;
        if (activeTab.value === 'trend' && trendMetric.value === 'temp') renderChart();
      } catch (e) { console.error(e); showToast('保存失败'); }
    }

    // ========== 猫咪管理 ==========
    function openAddCat() {
      catForm.name = ''; catForm.breed = ''; catForm.birthday = ''; catForm.avatar = '';
      errors.name = '';
      modal.addCat = true;
    }
    function openEditCat(cat) {
      editingCatId.value = cat.id;
      catForm.name = cat.name; catForm.breed = cat.breed || ''; catForm.birthday = cat.birthday || '';
      catForm.avatar = cat.avatar || '';
      errors.name = '';
      modal.editCat = true;
    }
    // 照片选择：压缩为 240x240 正方形 JPEG（约 20-50KB），存为 base64 随家庭同步
    function onAvatarPick(e) {
      var file = e.target.files && e.target.files[0];
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function () {
        var img = new Image();
        img.onload = function () {
          var size = 240;
          var canvas = document.createElement('canvas');
          canvas.width = size; canvas.height = size;
          var ctx = canvas.getContext('2d');
          // 居中裁剪为正方形（cover 效果）
          var s = Math.min(img.width, img.height);
          var sx = (img.width - s) / 2, sy = (img.height - s) / 2;
          ctx.drawImage(img, sx, sy, s, s, 0, 0, size, size);
          catForm.avatar = canvas.toDataURL('image/jpeg', 0.8);
        };
        img.src = reader.result;
      };
      reader.readAsDataURL(file);
      e.target.value = ''; // 允许重复选同一文件
    }
    function removeAvatar() { catForm.avatar = ''; }

    async function saveCat(isEdit) {
      if (!catForm.name.trim()) { errors.name = '请输入名字'; return; }
      try {
        if (isEdit) {
          await CatStore.updateCat(editingCatId.value, { name: catForm.name.trim(), breed: catForm.breed, birthday: catForm.birthday, avatar: catForm.avatar });
          showToast('已更新');
        } else {
          await CatStore.saveCat({ name: catForm.name.trim(), breed: catForm.breed, birthday: catForm.birthday, avatar: catForm.avatar });
          showToast('已添加猫咪');
        }
        await loadCats();
        if (!currentCatId.value && cats.value.length) { await switchCat(cats.value[0].id); }
        else if (isEdit && currentCatId.value === editingCatId.value) {
          // 刷新可能引用了猫名
        }
        modal.addCat = false; modal.editCat = false;
      } catch (e) { console.error(e); showToast('保存失败'); }
    }

    // ========== 用药计划 ==========
    function openAddPlan() {
      if (!currentCatId.value) return;
      planForm.cat_id = currentCatId.value;
      planForm.drug = ''; planForm.dose_amount = ''; planForm.dose_unit = '片'; planForm.remind_times = ['08:00'];
      planForm.freq_type = 'daily'; planForm.weekdays = []; planForm.interval_days = 2; planForm.remind_before = 0;
      planForm.start_date = todayStr(); planForm.end_date = ''; planForm.is_long_term = true; planForm.note = '';
      editingPlanId.value = null;
      errors.drug = '';
      modal.addPlan = true;
    }
    function openEditPlan(p) {
      editingPlanId.value = p.id;
      planForm.cat_id = p.cat_id;
      planForm.drug = p.drug;
      var pd = parseDose(p.dose);
      planForm.dose_amount = pd.amount; planForm.dose_unit = pd.unit;
      planForm.remind_times = (p.remind_times || []).slice();
      if (!planForm.remind_times.length) planForm.remind_times = ['08:00'];
      planForm.freq_type = p.freq_type || 'daily';
      planForm.weekdays = (p.weekdays || []).slice();
      planForm.interval_days = p.interval_days || 2;
      planForm.remind_before = p.remind_before || 0;
      planForm.start_date = p.start_date; planForm.end_date = p.end_date || '';
      planForm.is_long_term = !p.end_date; planForm.note = p.note || '';
      errors.drug = '';
      modal.editPlan = true;
    }
    function addPlanTime() { planForm.remind_times.push('08:00'); }
    function removePlanTime(idx) {
      if (planForm.remind_times.length > 1) planForm.remind_times.splice(idx, 1);
    }

    async function savePlan(isEdit) {
      if (!planForm.drug.trim()) { errors.drug = '请输入药品名'; return; }
      if (planForm.freq_type === 'weekly' && !planForm.weekdays.length) { errors.weekdays = '请选择每周哪几天服药'; return; }
      errors.weekdays = '';
      // 剂量：数字+单位 组合成标准文本（留空则不填剂量）
      var doseText = '';
      if (String(planForm.dose_amount).trim() !== '') {
        var da = parseFloat(planForm.dose_amount);
        if (isNaN(da) || da <= 0 || da > 9999) { errors.dose = '请输入正确的剂量数字'; return; }
        doseText = da + ' ' + planForm.dose_unit;
      }
      errors.dose = '';
      var payload = {
        cat_id: planForm.cat_id, drug: planForm.drug.trim(), dose: doseText,
        remind_times: planForm.remind_times.slice(), start_date: planForm.start_date,
        end_date: planForm.is_long_term ? null : (planForm.end_date || null),
        note: planForm.note.trim(), active: true,
        freq_type: planForm.freq_type,
        weekdays: planForm.freq_type === 'weekly' ? planForm.weekdays.slice() : null,
        interval_days: planForm.freq_type === 'interval' ? Math.min(30, Math.max(2, parseInt(planForm.interval_days) || 2)) : null,
        remind_before: parseInt(planForm.remind_before) || 0
      };
      try {
        if (isEdit) { await CatStore.updateMedPlan(editingPlanId.value, payload); showToast('计划已更新'); }
        else { await CatStore.saveMedPlan(payload); showToast('计划已创建'); }
        if (currentCatId.value) { await loadCatData(currentCatId.value); }
        modal.addPlan = false; modal.editPlan = false;
      } catch (e) { console.error(e); showToast('保存失败'); }
    }

    // 进行中 / 历史计划拆分（历史=已停用或已结束，可折叠查看）
    var ongoingPlans = computed(function () {
      return planList.value.filter(function (item) { return item.ongoing; });
    });
    var historyPlans = computed(function () {
      return planList.value.filter(function (item) { return !item.ongoing; });
    });
    var showHistory = ref(false);

    async function stopPlan(item) {
      if (!confirm('确定停用「' + item.plan.drug + '」？')) return;
      try {
        await CatStore.updateMedPlan(item.plan.id, { active: false });
        await loadCatData(currentCatId.value);
        showToast('已停用');
      } catch (e) { showToast('操作失败'); }
    }

    // 删除计划（连打卡记录一起清，不可恢复）
    async function deletePlan(item) {
      if (!confirm('确定删除「' + item.plan.drug + '」？\n该计划及其打卡记录将一并删除，不可恢复。')) return;
      try {
        await CatStore.deleteMedPlan(item.plan.id);
        await loadCatData(currentCatId.value);
        showToast('已删除');
      } catch (e) { console.error(e); showToast('删除失败'); }
    }
    // 编辑弹层中删除当前计划
    async function deletePlanFromModal() {
      if (!editingPlanId.value) return;
      var plan = plans.value.find(function (p) { return p.id === editingPlanId.value; });
      if (!confirm('确定删除「' + (plan ? plan.drug : '该计划') + '」？\n该计划及其打卡记录将一并删除，不可恢复。')) return;
      try {
        await CatStore.deleteMedPlan(editingPlanId.value);
        modal.addPlan = false; modal.editPlan = false;
        await loadCatData(currentCatId.value);
        showToast('已删除');
      } catch (e) { console.error(e); showToast('删除失败'); }
    }

    // ========== 生成 ICS 提醒日历 ==========
    function generateICS(item) {
      var plan = item.plan;
      var times = (plan.remind_times || []).slice();
      if (!times.length) { showToast('该计划无提醒时间'); return; }
      var lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//CatHealth//CN', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH'];
      var startDate = plan.start_date.replace(/-/g, '');
      times.forEach(function (time, idx) {
        var hm = time.split(':');
        var hh = pad(parseInt(hm[0])); var mm = pad(parseInt(hm[1]));
        var dt = startDate + 'T' + hh + mm + '00';
        lines.push('BEGIN:VEVENT');
        lines.push('UID:cathealth-' + plan.id + '-' + idx + '@cat-health');
        lines.push('DTSTART:' + dt);
        var rrule;
        var ft = plan.freq_type || 'daily';
        if (ft === 'weekly') {
          var wdMap = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
          var byday = (plan.weekdays || []).map(function (d) { return wdMap[d]; }).join(',');
          rrule = 'RRULE:FREQ=WEEKLY' + (byday ? ';BYDAY=' + byday : '');
        } else if (ft === 'interval') {
          rrule = 'RRULE:FREQ=DAILY;INTERVAL=' + (parseInt(plan.interval_days) || 1);
        } else {
          rrule = 'RRULE:FREQ=DAILY';
        }
        if (plan.end_date) { rrule += ';UNTIL=' + plan.end_date.replace(/-/g, '') + 'T235959'; }
        lines.push(rrule);
        var summary = plan.drug + (plan.dose ? ' ' + plan.dose : '');
        lines.push('SUMMARY:' + icsEscape(summary));
        if (plan.note) lines.push('DESCRIPTION:' + icsEscape(plan.note));
        lines.push('BEGIN:VALARM');
        // 按计划的提前量提醒：用药时间前 N 分钟触发
        lines.push('TRIGGER:-PT' + (parseInt(plan.remind_before) || 0) + 'M');
        lines.push('ACTION:DISPLAY');
        lines.push('DESCRIPTION:' + icsEscape('该给猫咪喂 ' + plan.drug + ' 了'));
        lines.push('END:VALARM');
        lines.push('END:VEVENT');
      });
      lines.push('END:VCALENDAR');
      var blob = new Blob([lines.join('\r\n')], { type: 'text/calendar;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url; a.download = (plan.drug + '-提醒.ics').replace(/\s+/g, '');
      document.body.appendChild(a); a.click(); document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showToast('已下载 .ics，打开后添加到日历');
    }
    function icsEscape(s) { return String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n'); }

    // ========== 趋势图表 ==========
    function getTrendData() {
      var arr = trendMetric.value === 'weight' ? weights.value : temps.value;
      var now = new Date();
      if (trendRange.value !== 'all') {
        var days = parseInt(trendRange.value);
        var cutoff = new Date(now.getTime() - days * 86400000);
        arr = arr.filter(function (r) { return new Date(r.date) >= cutoff; });
      }
      // 按日期去重：同一天多条只保留最新一条（后者覆盖前者），兼容历史重复数据
      var byDate = {};
      arr.forEach(function (r) { byDate[r.date] = r; });
      return Object.keys(byDate).sort().map(function (d) { return byDate[d]; });
    }

    function renderChart() {
      if (!chartRef.value) return;
      if (typeof echarts === 'undefined') return;
      if (!chartInstance) chartInstance = echarts.init(chartRef.value);
      var data = getTrendData();
      var isWeight = trendMetric.value === 'weight';
      var unit = isWeight ? 'kg' : '°C';
      var valKey = isWeight ? 'kg' : 'celsius';
      var dates = data.map(function (r) { return r.date; });
      var vals = data.map(function (r) { return parseFloat(r[valKey]); });
      // 最新值（默认定位点）放大高亮，进页面即聚焦
      var lastIdx = vals.length - 1;
      var accent = isWeight ? '#237a5c' : '#d35d46';
      var seriesData = vals.map(function (v, i) {
        if (i === lastIdx) return { value: v, symbolSize: 10, itemStyle: { color: '#fff', borderColor: accent, borderWidth: 3 } };
        return v;
      });

      var series = {
        name: isWeight ? '体重' : '体温', type: 'line', data: seriesData, smooth: true,
        symbol: 'circle', symbolSize: 6, lineStyle: { width: 3, color: accent },
        itemStyle: { color: accent },
        areaStyle: { color: isWeight ? 'rgba(35,122,92,0.08)' : 'rgba(211,93,70,0.08)' }
      };
      var option = {
        grid: { left: 48, right: 20, top: 32, bottom: 34 },
        tooltip: { trigger: 'axis', formatter: function (p) { return p[0].name + '<br/>' + p[0].value + ' ' + unit; } },
        xAxis: {
          type: 'category', data: dates,
          name: '日期', nameLocation: 'middle', nameGap: 24,
          nameTextStyle: { fontSize: 11, color: '#8e8e93' },
          axisLabel: { fontSize: 10, formatter: function (v) { var p = v.split('-'); return p[1] + '/' + p[2]; } }
        },
        yAxis: {
          type: 'value', scale: true, splitNumber: 4,
          name: isWeight ? '体重 (kg)' : '体温 (°C)',
          nameTextStyle: { fontSize: 11, color: '#8e8e93', align: 'left' },
          axisLabel: { fontSize: 11 },
          // 纵轴按数据范围留足余量：体重 ±0.3kg、体温 ±0.5°C，
          // 0.1kg 级的日常波动在图上只是小起伏，不会显得"剧烈波动"
          min: function (v) { return isWeight ? Math.max(0, Math.floor((v.min - 0.3) * 10) / 10) : Math.floor((v.min - 0.5) * 10) / 10; },
          max: function (v) { return isWeight ? Math.ceil((v.max + 0.3) * 10) / 10 : Math.ceil((v.max + 0.5) * 10) / 10; }
        },
        series: [series]
      };
      // 体温正常区间
      if (!isWeight) {
        series.markArea = {
          silent: true, itemStyle: { color: 'rgba(52,199,89,0.12)' },
          data: [[{ yAxis: 38.0 }, { yAxis: 39.2 }]]
        };
        series.markLine = {
          silent: true, symbol: 'none', lineStyle: { color: '#34c759', type: 'dashed', width: 1 },
          data: [{ yAxis: 38.0 }, { yAxis: 39.2 }]
        };
      }
      chartInstance.setOption(option, true);
      // 进入趋势页默认聚焦最新（当天）的值：自动弹出该点提示
      if (vals.length) {
        chartInstance.dispatchAction({ type: 'showTip', seriesIndex: 0, dataIndex: lastIdx });
      }
    }

    // 趋势统计卡
    var trendStats = computed(function () {
      var data = getTrendData();
      if (!data.length) return { current: '-', change: '-', count: 0 };
      var valKey = trendMetric.value === 'weight' ? 'kg' : 'celsius';
      var unit = trendMetric.value === 'weight' ? 'kg' : '°C';
      var current = parseFloat(data[data.length - 1][valKey]);
      var first = parseFloat(data[0][valKey]);
      var change = (current - first).toFixed(trendMetric.value === 'weight' ? 2 : 1);
      var sign = change > 0 ? '+' : '';
      return {
        current: current + ' ' + unit,
        change: sign + change + ' ' + unit,
        count: data.length
      };
    });

    watch([trendMetric, trendRange], function () { nextTick(renderChart); });

    // ========== 家庭同步 ==========
    function getFamilyId() { return CatStore.getFamilyId(); }
    var isSync = computed(function () { return CatStore.isSyncMode(); });
    var hasSupabase = computed(function () { return CatStore.hasSupabase && CatStore.hasSupabase(); });

    async function createFamily() {
      if (!hasSupabase.value) { showToast('请先在 config.js 中配置 Supabase'); return; }
      loading.value = true;
      try {
        var fid = await CatStore.createFamily();
        showToast('家庭已创建');
        await loadCats();
        if (cats.value.length) await switchCat(cats.value[0].id);
      } catch (e) { console.error(e); showToast('创建失败，请重试'); }
      finally { loading.value = false; }
    }

    function openJoinFamily() { joinCode.value = ''; modal.joinFamily = true; }

    async function doJoinFamily() {
      if (!joinCode.value.trim()) { showToast('请输入家庭码'); return; }
      if (!hasSupabase.value) { showToast('请先在 config.js 中配置 Supabase'); return; }
      loading.value = true;
      try {
        await CatStore.joinFamily(joinCode.value.trim());
        showToast('已加入家庭');
        modal.joinFamily = false;
        await loadCats();
        if (cats.value.length) await switchCat(cats.value[0].id);
        else showToast('该家庭暂无猫咪数据');
      } catch (e) { console.error(e); showToast('加入失败，请检查家庭码'); }
      finally { loading.value = false; }
    }

    function copyFamilyCode() {
      var fid = CatStore.getFamilyId() || '';
      if (!fid) return;
      if (navigator.clipboard) {
        navigator.clipboard.writeText(fid).then(function () { showToast('已复制'); });
      } else {
        var ta = document.createElement('textarea'); ta.value = fid;
        document.body.appendChild(ta); ta.select(); document.execCommand('copy');
        document.body.removeChild(ta); showToast('已复制');
      }
    }

    // ========== 数据备份 ==========
    async function exportData() {
      try {
        var json = await CatStore.exportAll();
        var blob = new Blob([json], { type: 'application/json' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url; a.download = 'cat-health-backup-' + todayStr() + '.json';
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
        URL.revokeObjectURL(url);
        showToast('已导出备份');
      } catch (e) { console.error(e); showToast('导出失败'); }
    }

    function openImport() { importText.value = ''; modal.importData = true; }

    function onImportFile(ev) {
      var file = ev.target.files[0];
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function (e) { importText.value = e.target.result; };
      reader.readAsText(file);
    }

    async function doImport() {
      if (!importText.value.trim()) { showToast('请选择文件或粘贴内容'); return; }
      try {
        await CatStore.importAll(importText.value);
        await loadCats();
        if (cats.value.length) await switchCat(cats.value[0].id);
        modal.importData = false;
        showToast('导入成功');
      } catch (e) { console.error(e); showToast('导入失败，请检查格式'); }
    }

    // ========== 初始化 ==========
    onMounted(async function () {
      await loadCats();
      if (cats.value.length) {
        await switchCat(cats.value[0].id);
      } else {
        // 自动打开添加猫咪弹窗
        modal.addCat = true;
      }
      // 监听窗口尺寸变化重绘图表
      window.addEventListener('resize', function () { if (chartInstance) chartInstance.resize(); });
    });

    // ========== 暴露 ==========
    return {
      activeTab, showCatMenu, loading, toastMsg, cats, currentCatId, currentCat, hasCats,
      weights, temps, plans, allLogs, todayTasks, todayPending, recentRecords, planList,
      trendMetric, trendRange, chartRef, trendStats,
      modal, catForm, editingCatId, weightForm, tempForm, planForm, editingPlanId,
      joinCode, importText, errors,
      isSync, getFamilyId,
      // v2.0 首页总览
      greeting, todayLabel, latestWeight, latestTemp, weightDelta, tempStatus,
      doseDone, doseTotal, nextDose, careTip, trendRecords,
      iconSvg, catAge, editCurrentCat, openQuickRecord, pickRecordType, remindTimeOf, activePlans,
      switchTab, switchCat, showToast,
      markTaken, markSkipped,
      openAddWeight, openAddTemp, saveWeight, saveTemp, openEditRecord, deleteWeightRecord, deleteTempRecord,
      openAddCat, openEditCat, saveCat, onAvatarPick, removeAvatar,
      openAddPlan, openEditPlan, savePlan, addPlanTime, removePlanTime, stopPlan, deletePlan, deletePlanFromModal,
      ongoingPlans, historyPlans, showHistory,
      generateICS, weekdayOptions, toggleWeekday, freqText, isDoseDay,
      renderChart,
      createFamily, openJoinFamily, doJoinFamily, copyFamilyCode,
      exportData, openImport, onImportFile, doImport,
      todayStr, fmtDate, fmtDateTime
    };
  }
}).mount('#app');
