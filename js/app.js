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
      addWeight: false, addTemp: false,
      addPlan: false, editPlan: false,
      joinFamily: false, importData: false
    });
    var catForm = reactive({ name: '', breed: '', birthday: '', avatar: '' });
    var editingCatId = ref(null);
    var weightForm = reactive({ id: null, cat_id: null, date: todayStr(), kg: '', note: '' });
    var tempForm = reactive({ id: null, cat_id: null, date: todayStr(), celsius: '', note: '' });
    var planForm = reactive({
      cat_id: null, drug: '', dose: '', remind_times: ['08:00'],
      start_date: todayStr(), end_date: '', is_long_term: true, note: ''
    });
    var editingPlanId = ref(null);
    var joinCode = ref('');
    var importText = ref('');
    var errors = reactive({});

    // ========== 计算属性 ==========
    var currentCat = computed(function () {
      return cats.value.find(function (c) { return c.id === currentCatId.value; }) || null;
    });
    var hasCats = computed(function () { return cats.value.length > 0; });

    // 今日用药任务
    var todayTasks = computed(function () {
      var today = todayStr();
      var now = new Date();
      var tasks = [];
      var catPlans = plans.value.filter(function (p) {
        return p.cat_id === currentCatId.value && p.active &&
          p.start_date <= today && (!p.end_date || p.end_date >= today);
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
      planForm.drug = ''; planForm.dose = ''; planForm.remind_times = ['08:00'];
      planForm.start_date = todayStr(); planForm.end_date = ''; planForm.is_long_term = true; planForm.note = '';
      editingPlanId.value = null;
      errors.drug = '';
      modal.addPlan = true;
    }
    function openEditPlan(item) {
      var p = item.plan;
      editingPlanId.value = p.id;
      planForm.cat_id = p.cat_id;
      planForm.drug = p.drug; planForm.dose = p.dose || '';
      planForm.remind_times = (p.remind_times || []).slice();
      if (!planForm.remind_times.length) planForm.remind_times = ['08:00'];
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
      var payload = {
        cat_id: planForm.cat_id, drug: planForm.drug.trim(), dose: planForm.dose.trim(),
        remind_times: planForm.remind_times.slice(), start_date: planForm.start_date,
        end_date: planForm.is_long_term ? null : (planForm.end_date || null),
        note: planForm.note.trim(), active: true
      };
      try {
        if (isEdit) { await CatStore.updateMedPlan(editingPlanId.value, payload); showToast('计划已更新'); }
        else { await CatStore.saveMedPlan(payload); showToast('计划已创建'); }
        if (currentCatId.value) { await loadCatData(currentCatId.value); }
        modal.addPlan = false; modal.editPlan = false;
      } catch (e) { console.error(e); showToast('保存失败'); }
    }

    async function stopPlan(item) {
      if (!confirm('确定停用「' + item.plan.drug + '」？')) return;
      try {
        await CatStore.updateMedPlan(item.plan.id, { active: false });
        await loadCatData(currentCatId.value);
        showToast('已停用');
      } catch (e) { showToast('操作失败'); }
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
        var rrule = 'RRULE:FREQ=DAILY';
        if (plan.end_date) { rrule += ';UNTIL=' + plan.end_date.replace(/-/g, '') + 'T235959'; }
        lines.push(rrule);
        var summary = plan.drug + (plan.dose ? ' ' + plan.dose : '');
        lines.push('SUMMARY:' + icsEscape(summary));
        if (plan.note) lines.push('DESCRIPTION:' + icsEscape(plan.note));
        lines.push('BEGIN:VALARM');
        lines.push('TRIGGER:-PT0M');
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

      var series = {
        name: isWeight ? '体重' : '体温', type: 'line', data: vals, smooth: true,
        symbol: 'circle', symbolSize: 6, lineStyle: { width: 2, color: isWeight ? '#ff7a7a' : '#007aff' },
        itemStyle: { color: isWeight ? '#ff7a7a' : '#007aff' },
        areaStyle: { color: isWeight ? 'rgba(255,122,122,0.1)' : 'rgba(0,122,255,0.1)' }
      };
      var option = {
        grid: { left: 45, right: 16, top: 20, bottom: 30 },
        tooltip: { trigger: 'axis', formatter: function (p) { return p[0].name + '<br/>' + p[0].value + ' ' + unit; } },
        xAxis: { type: 'category', data: dates, axisLabel: { fontSize: 10, formatter: function (v) { var p = v.split('-'); return p[1] + '/' + p[2]; } } },
        yAxis: {
          type: 'value', scale: true, splitNumber: 4,
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
      activeTab, loading, toastMsg, cats, currentCatId, currentCat, hasCats,
      weights, temps, plans, allLogs, todayTasks, todayPending, recentRecords, planList,
      trendMetric, trendRange, chartRef, trendStats,
      modal, catForm, editingCatId, weightForm, tempForm, planForm, editingPlanId,
      joinCode, importText, errors,
      isSync, getFamilyId,
      switchTab, switchCat, showToast,
      markTaken, markSkipped,
      openAddWeight, openAddTemp, saveWeight, saveTemp, openEditRecord, deleteWeightRecord, deleteTempRecord,
      openAddCat, openEditCat, saveCat, onAvatarPick, removeAvatar,
      openAddPlan, openEditPlan, savePlan, addPlanTime, removePlanTime, stopPlan,
      generateICS,
      renderChart,
      createFamily, openJoinFamily, doJoinFamily, copyFamilyCode,
      exportData, openImport, onImportFile, doImport,
      todayStr, fmtDate, fmtDateTime
    };
  }
}).mount('#app');
