-- NGUY HIỂM: XÓA TOÀN BỘ DỮ LIỆU (kể cả nhật ký). Chỉ dùng để dọn dữ liệu mô phỏng trên database thử.
-- Chạy bằng quyền quản trị. KHÔNG chạy trên database có dữ liệu thật của quán.
do $$ begin
  if to_regclass('public.sim_ground_truth') is not null then
    truncate sim_ground_truth;
  end if;
end $$;
truncate shop_invites, user_settings, pin_attempts, audit_log, cash_movements, stock_ledger, waste_logs, stock_counts, purchases,
         bill_lines, bills, shifts, recipe_lines, menu_sizes, menu_items, dining_tables, areas,
         ingredients, staff, shops restart identity cascade;
