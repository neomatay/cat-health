// ============================================================
// 猫咪健康 PWA - 数据层 store.js
// 本地模式(localStorage) / 同步模式(Supabase) 对页面透明
// ============================================================
(function () {
  'use strict';

  var CFG = window.CAT_HEALTH_CONFIG || {};
  var LS_FAMILY = 'cat_health_family_id';
  var LS_PREFIX = 'cat_health_';
  var supa = null;

  // 初始化 Supabase 客户端（若已配置）
  function initSupabase() {
    if (!CFG.SUPABASE_URL || !CFG.SUPABASE_ANON_KEY) return null;
    try {
      if (window.supabase && typeof window.supabase.createClient === 'function') {
        supa = window.supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY);
      }
    } catch (e) { console.warn('Supabase 初始化失败:', e); }
    return supa;
  }

  function isSyncMode() { return !!supa; }

  // ---- UUID ----
  function uuid() {
    if (window.crypto && typeof window.crypto.randomUUID === 'function') {
      return window.crypto.randomUUID();
    }
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      var r = Math.random() * 16 | 0; var v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  // ---- localStorage 读写 ----
  function lsGet(key) {
    try { return JSON.parse(localStorage.getItem(LS_PREFIX + key) || 'null'); }
    catch (e) { return null; }
  }
  function lsSet(key, val) { localStorage.setItem(LS_PREFIX + key, JSON.stringify(val)); }
  function lsGetArr(key) { var a = lsGet(key); return Array.isArray(a) ? a : []; }
  function lsSaveArr(key, arr) { lsSet(key, arr); }

  // ---- family_id ----
  function getFamilyId() { return localStorage.getItem(LS_FAMILY) || null; }
  function setFamilyId(id) { localStorage.setItem(LS_FAMILY, id); }
  function clearFamilyId() { localStorage.removeItem(LS_FAMILY); }

  // 确保有 family_id（本地模式下首次使用自动生成）
  function ensureFamilyId() {
    var fid = getFamilyId();
    if (!fid) { fid = uuid(); setFamilyId(fid); }
    return fid;
  }

  // ---- 工具：为本地记录补 family_id ----
  function withFid(obj) { var fid = getFamilyId(); var o = Object.assign({}, obj); o.family_id = fid; return o; }

  // ============================================================
  // 本地模式 CRUD
  // ============================================================
  function localList(table, filterFn) {
    var arr = lsGetArr(table);
    return arr.filter(filterFn || function () { return true; });
  }
  function localInsert(table, record) {
    var arr = lsGetArr(table);
    arr.push(record); lsSaveArr(table, arr);
  }
  function localUpdate(table, id, patch) {
    var arr = lsGetArr(table);
    for (var i = 0; i < arr.length; i++) {
      if (arr[i].id === id) { arr[i] = Object.assign({}, arr[i], patch); break; }
    }
    lsSaveArr(table, arr);
  }
  function localDelete(table, id) {
    var arr = lsGetArr(table).filter(function (r) { return r.id !== id; });
    lsSaveArr(table, arr);
  }

  // ============================================================
  // 统一 API（全部返回 Promise）
  // ============================================================
  var Store = {
    uuid: uuid,
    isSyncMode: isSyncMode,
    getFamilyId: getFamilyId,
    setFamilyId: setFamilyId,
    clearFamilyId: clearFamilyId,
    ensureFamilyId: ensureFamilyId,

    // ---- 猫咪 ----
    getCats: function () {
      var fid = getFamilyId();
      if (isSyncMode()) {
        return supa.from('cats').select('*').eq('family_id', fid).order('created_at')
          .then(function (r) { return r.data || []; })
          .catch(function (e) { console.error('getCats', e); throw e; });
      }
      return Promise.resolve(localList('cats', function (c) { return c.family_id === fid; }));
    },
    saveCat: function (cat) {
      var fid = getFamilyId();
      var rec = Object.assign({ id: uuid(), family_id: fid, created_at: new Date().toISOString() }, cat);
      if (isSyncMode()) {
        return supa.from('cats').insert(rec).select().then(function (r) {
          if (r.error) throw r.error; return (r.data && r.data[0]) || rec;
        });
      }
      localInsert('cats', rec); return Promise.resolve(rec);
    },
    updateCat: function (id, patch) {
      if (isSyncMode()) {
        return supa.from('cats').update(patch).eq('id', id).select().then(function (r) {
          if (r.error) throw r.error; return (r.data && r.data[0]) || patch;
        });
      }
      localUpdate('cats', id, patch); return Promise.resolve(patch);
    },
    deleteCat: function (id) {
      if (isSyncMode()) {
        return supa.from('cats').delete().eq('id', id).then(function (r) { if (r.error) throw r.error; });
      }
      localDelete('cats', id); return Promise.resolve();
    },

    // ---- 体重 ----
    getWeights: function (catId) {
      var fid = getFamilyId();
      if (isSyncMode()) {
        var q = supa.from('weights').select('*').eq('family_id', fid).eq('cat_id', catId).order('date', { ascending: true });
        return q.then(function (r) { return r.data || []; });
      }
      return Promise.resolve(localList('weights', function (w) { return w.cat_id === catId; })
        .sort(function (a, b) { return (a.date || '').localeCompare(b.date || ''); }));
    },
    addWeight: function (rec) {
      var r = withFid(Object.assign({ id: uuid(), created_at: new Date().toISOString() }, rec));
      if (isSyncMode()) {
        return supa.from('weights').insert(r).select().then(function (res) {
          if (res.error) throw res.error; return (res.data && res.data[0]) || r;
        });
      }
      localInsert('weights', r); return Promise.resolve(r);
    },

    // ---- 体温 ----
    getTemps: function (catId) {
      var fid = getFamilyId();
      if (isSyncMode()) {
        return supa.from('temps').select('*').eq('family_id', fid).eq('cat_id', catId).order('date', { ascending: true })
          .then(function (r) { return r.data || []; });
      }
      return Promise.resolve(localList('temps', function (t) { return t.cat_id === catId; })
        .sort(function (a, b) { return (a.date || '').localeCompare(b.date || ''); }));
    },
    addTemp: function (rec) {
      var r = withFid(Object.assign({ id: uuid(), created_at: new Date().toISOString() }, rec));
      if (isSyncMode()) {
        return supa.from('temps').insert(r).select().then(function (res) {
          if (res.error) throw res.error; return (res.data && res.data[0]) || r;
        });
      }
      localInsert('temps', r); return Promise.resolve(r);
    },

    // ---- 用药计划 ----
    getMedPlans: function (catId) {
      var fid = getFamilyId();
      if (isSyncMode()) {
        var q = supa.from('med_plans').select('*').eq('family_id', fid);
        if (catId) q = q.eq('cat_id', catId);
        return q.order('created_at').then(function (r) { return r.data || []; });
      }
      return Promise.resolve(localList('med_plans', function (p) {
        return p.family_id === fid && (!catId || p.cat_id === catId);
      }));
    },
    saveMedPlan: function (plan) {
      var fid = getFamilyId();
      var rec = Object.assign({ id: uuid(), family_id: fid, active: true, created_at: new Date().toISOString() }, plan);
      if (isSyncMode()) {
        return supa.from('med_plans').insert(rec).select().then(function (r) {
          if (r.error) throw r.error; return (r.data && r.data[0]) || rec;
        });
      }
      localInsert('med_plans', rec); return Promise.resolve(rec);
    },
    updateMedPlan: function (id, patch) {
      if (isSyncMode()) {
        return supa.from('med_plans').update(patch).eq('id', id).select().then(function (r) {
          if (r.error) throw r.error; return (r.data && r.data[0]) || patch;
        });
      }
      localUpdate('med_plans', id, patch); return Promise.resolve(patch);
    },

    // ---- 用药打卡记录 ----
    getMedLogs: function (opts) {
      var fid = getFamilyId();
      opts = opts || {};
      if (isSyncMode()) {
        var q = supa.from('med_logs').select('*').eq('family_id', fid);
        if (opts.plan_id) q = q.eq('plan_id', opts.plan_id);
        if (opts.date) q = q.eq('date', opts.date);
        return q.then(function (r) { return r.data || []; });
      }
      return Promise.resolve(localList('med_logs', function (l) {
        if (l.family_id !== fid) return false;
        if (opts.plan_id && l.plan_id !== opts.plan_id) return false;
        if (opts.date && l.date !== opts.date) return false;
        return true;
      }));
    },
    // 查找某条计划在 date+scheduled_time 的打卡记录
    findMedLog: function (planId, date, time) {
      if (isSyncMode()) {
        return supa.from('med_logs').select('*').eq('plan_id', planId).eq('date', date).eq('scheduled_time', time)
          .then(function (r) { return (r.data && r.data[0]) || null; });
      }
      var arr = localList('med_logs', function (l) { return l.plan_id === planId && l.date === date && l.scheduled_time === time; });
      return Promise.resolve(arr[0] || null);
    },
    upsertMedLog: function (log) {
      var fid = getFamilyId();
      var rec = withFid(Object.assign({ id: uuid(), created_at: new Date().toISOString() }, log));
      if (isSyncMode()) {
        // 利用唯一约束 (plan_id, date, scheduled_time) 做 upsert
        return supa.from('med_logs').upsert(rec, { onConflict: 'plan_id,date,scheduled_time' }).select()
          .then(function (r) { if (r.error) throw r.error; return (r.data && r.data[0]) || rec; });
      }
      // 本地：先找
      var arr = lsGetArr('med_logs');
      var found = -1;
      for (var i = 0; i < arr.length; i++) {
        if (arr[i].plan_id === rec.plan_id && arr[i].date === rec.date && arr[i].scheduled_time === rec.scheduled_time) {
          found = i; break;
        }
      }
      if (found >= 0) { arr[found] = Object.assign({}, arr[found], rec); }
      else { arr.push(rec); }
      lsSaveArr('med_logs', arr);
      return Promise.resolve(rec);
    },

    // ============================================================
    // 家庭同步：创建家庭 / 加入家庭
    // ============================================================
    createFamily: function () {
      // 生成新 UUID 作 family_id，将本地所有数据迁移到云端
      var fid = uuid();
      // 收集本地所有数据（当前 family_id 下的）
      var oldFid = getFamilyId();
      var localData = collectLocalData(oldFid);
      // 把每条记录的 family_id 更新为新的 fid
      localData.cats.forEach(function (c) { c.family_id = fid; });
      localData.weights.forEach(function (c) { c.family_id = fid; });
      localData.temps.forEach(function (c) { c.family_id = fid; });
      localData.med_plans.forEach(function (c) { c.family_id = fid; });
      localData.med_logs.forEach(function (c) { c.family_id = fid; });

      return uploadData(localData).then(function () {
        setFamilyId(fid);
        // 清空本地缓存（切换到云端）
        clearLocalTables();
        return fid;
      });
    },

    joinFamily: function (code) {
      // 验证能否拉到数据
      return supa.from('cats').select('id').eq('family_id', code).limit(1).then(function (r) {
        if (r.error) throw r.error;
        // 设置 family_id，清空本地，拉取远端到本地缓存
        setFamilyId(code);
        clearLocalTables();
        return pullAllToLocal(code).then(function () { return code; });
      });
    },

    // ---- 备份导出/导入 ----
    exportAll: function () {
      var fid = getFamilyId();
      if (isSyncMode()) {
        // 从云端拉取全部
        return collectRemoteData(fid).then(function (data) {
          return JSON.stringify({ family_id: fid, exported_at: new Date().toISOString(), data: data }, null, 2);
        });
      }
      var data = collectLocalData(fid);
      return Promise.resolve(JSON.stringify({ family_id: fid, exported_at: new Date().toISOString(), data: data }, null, 2));
    },

    importAll: function (jsonStr) {
      var parsed = JSON.parse(jsonStr);
      var data = parsed.data || parsed;
      var fid = getFamilyId();
      // 为导入数据适配当前 family_id
      function stamp(arr) { return (arr || []).map(function (r) { r.family_id = fid; return r; }); }
      data.cats = stamp(data.cats); data.weights = stamp(data.weights);
      data.temps = stamp(data.temps); data.med_plans = stamp(data.med_plans); data.med_logs = stamp(data.med_logs);

      if (isSyncMode()) {
        return uploadData(data).then(function () { return true; });
      }
      // 本地：直接覆盖写入
      lsSaveArr('cats', data.cats); lsSaveArr('weights', data.weights);
      lsSaveArr('temps', data.temps); lsSaveArr('med_plans', data.med_plans);
      lsSaveArr('med_logs', data.med_logs);
      return Promise.resolve(true);
    }
  };

  // ---- 辅助：收集本地数据 ----
  function collectLocalData(fid) {
    return {
      cats: localList('cats', function (c) { return c.family_id === fid; }),
      weights: localList('weights', function (c) { return c.family_id === fid; }),
      temps: localList('temps', function (c) { return c.family_id === fid; }),
      med_plans: localList('med_plans', function (c) { return c.family_id === fid; }),
      med_logs: localList('med_logs', function (c) { return c.family_id === fid; })
    };
  }

  // ---- 辅助：收集远端数据 ----
  function collectRemoteData(fid) {
    var tables = ['cats', 'weights', 'temps', 'med_plans', 'med_logs'];
    var result = {};
    return Promise.all(tables.map(function (t) {
      return supa.from(t).select('*').eq('family_id', fid).then(function (r) { result[t] = r.data || []; });
    })).then(function () { return result; });
  }

  // ---- 辅助：上传数据到云端 ----
  function uploadData(data) {
    var tables = ['cats', 'weights', 'temps', 'med_plans', 'med_logs'];
    return Promise.all(tables.map(function (t) {
      if (!data[t] || data[t].length === 0) return Promise.resolve();
      return supa.from(t).insert(data[t]).then(function (r) { if (r.error) console.warn('上传 ' + t + ' 失败:', r.error); });
    }));
  }

  // ---- 辅助：拉取远端数据到本地缓存 ----
  function pullAllToLocal(fid) {
    return collectRemoteData(fid).then(function (data) {
      lsSaveArr('cats', data.cats); lsSaveArr('weights', data.weights);
      lsSaveArr('temps', data.temps); lsSaveArr('med_plans', data.med_plans);
      lsSaveArr('med_logs', data.med_logs);
    });
  }

  function clearLocalTables() {
    ['cats', 'weights', 'temps', 'med_plans', 'med_logs'].forEach(function (t) {
      localStorage.removeItem(LS_PREFIX + t);
    });
  }

  // 初始化
  initSupabase();
  // 本地模式下确保有 family_id
  if (!isSyncMode()) ensureFamilyId();

  window.CatStore = Store;
})();
