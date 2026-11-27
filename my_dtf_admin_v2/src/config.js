// Configuration d'une installation My DTF. Chaque atelier a ses propres valeurs :
// les fournir au build (fichier .env ou variables VITE_*), sans toucher au code.
const env = import.meta.env;
export const CONFIG = {
  supabaseUrl: env.VITE_SUPABASE_URL || 'https://pxifieuohgthtqkwasug.supabase.co',
  supabaseAnonKey: env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4aWZpZXVvaGd0aHRxa3dhc3VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMzI3NDUsImV4cCI6MjEwODcwODc0NX0.pXYktWDzEcjzcwEFspJnul1zzdSkmiWlMra2ukQkG8k',
  appName: env.VITE_APP_NAME || 'My DTF',
  adminUrl: env.VITE_ADMIN_URL || 'mydtf-admin.pages.dev',
  clientUrl: env.VITE_CLIENT_URL || 'mydtf.pages.dev',
};
