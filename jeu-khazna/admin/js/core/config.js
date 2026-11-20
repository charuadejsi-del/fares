// إعدادات عامة. المفتاح العام (anon) مصمَّم ليكون في الواجهة؛ الحماية الحقيقية في RLS ودوالّ المدير.
export const SUPABASE_URL = 'https://ubdamgzqqwgcxjvvegwk.supabase.co';
export const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InViZGFtZ3pxcXdnY3hqdnZlZ3drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4ODAzNzksImV4cCI6MjExMDQ1NjM3OX0.eAQ0bOVJ139YKR3VUOa3mQNV5BOeALEYV4zyobD48RI';

export const POLL_MS = 15000;
export const LOW_BALANCE_SECONDS = 600;

export const REGIONS = [
  { name: 'الميناء', color: '#00ffa3', from: 1, to: 20 },
  { name: 'النهر', color: '#22c7ff', from: 21, to: 40 },
  { name: 'الجبل', color: '#ffb547', from: 41, to: 60 },
];

/** أسباب حركات الوقت: [النص، اللون] */
export const REASONS = {
  signup: ['هدية التسجيل', 'ok'],
  daily: ['الوقت اليومي', 'info'],
  session: ['وقت لعب', 'violet'],
  penalty: ['عقوبة خطأ', 'danger'],
  purchase: ['شراء', 'warn'],
  gift_in: ['هدية مستلمة', 'ok'],
  gift_out: ['هدية مُرسلة', 'violet'],
  hint: ['تلميح', 'info'],
  admin: ['تعديل المدير', 'warn'],
  referral: ['مكافأة دعوة', 'ok'],
  challenge: ['تحدٍّ يومي', 'violet'],
};
