// ============================================================
// 猫咪健康 PWA 配置
// ============================================================
// 未配置 Supabase 时，应用自动使用 localStorage 本地存储，完全可用。
// 配置后可启用云端同步（创建/加入家庭）。
//
// 获取方式：
//   1. 访问 https://supabase.com 注册并创建项目
//   2. 项目设置 → API → 获取 Project URL 与 anon public key
//   3. 在 Supabase SQL Editor 中执行 supabase-setup.sql
//   4. 将下方两个值填入即可
// ============================================================
window.CAT_HEALTH_CONFIG = {
  SUPABASE_URL: 'https://pvprdtfkqqxkwxvstzuo.supabase.co',      // 例如 'https://xxxxxxxx.supabase.co'
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2cHJkdGZrcXF4a3d4dnN0enVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU2NTgyNjUsImV4cCI6MjEwMTIzNDI2NX0.FeX0-FBeIKcgQEefuUr5m1ufANIRe1bjoE2Nz-22mb8'  // anon public key
};
