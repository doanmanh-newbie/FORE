-- Run only on the disposable local test database after rebuild_test_database.sql.
-- Creates two shops, checks same-shop references, and rolls everything back.
begin;

insert into auth.users (id, email) values
  ('94000000-0000-0000-0000-000000000001', 'owner-a@test.invalid'),
  ('94000000-0000-0000-0000-000000000002', 'owner-b@test.invalid');
insert into shops (id, name, created_by) values
  ('94000000-0000-0000-0000-000000000010', 'tenant A', '94000000-0000-0000-0000-000000000001'),
  ('94000000-0000-0000-0000-000000000020', 'tenant B', '94000000-0000-0000-0000-000000000002');
insert into staff (id, shop_id, auth_user_id, full_name, role) values
  ('94000000-0000-0000-0000-000000000011', '94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000001', 'Owner A', 'owner'),
  ('94000000-0000-0000-0000-000000000021', '94000000-0000-0000-0000-000000000020', '94000000-0000-0000-0000-000000000002', 'Owner B', 'owner');
insert into ingredients (id, shop_id, name, unit) values
  ('94000000-0000-0000-0000-000000000031', '94000000-0000-0000-0000-000000000010', 'Ingredient A', 'g'),
  ('94000000-0000-0000-0000-000000000032', '94000000-0000-0000-0000-000000000020', 'Ingredient B', 'g');
insert into suppliers (id, shop_id, name) values
  ('94000000-0000-0000-0000-000000000041', '94000000-0000-0000-0000-000000000010', 'Supplier A'),
  ('94000000-0000-0000-0000-000000000042', '94000000-0000-0000-0000-000000000020', 'Supplier B');
insert into purchase_orders (id, shop_id, code, supplier_id, created_by) values
  ('94000000-0000-0000-0000-000000000051', '94000000-0000-0000-0000-000000000010', 'PO-A', '94000000-0000-0000-0000-000000000041', '94000000-0000-0000-0000-000000000011'),
  ('94000000-0000-0000-0000-000000000052', '94000000-0000-0000-0000-000000000020', 'PO-B', '94000000-0000-0000-0000-000000000042', '94000000-0000-0000-0000-000000000021');
insert into purchase_order_lines (id, shop_id, order_id, ingredient_id, qty) values
  ('94000000-0000-0000-0000-000000000061', '94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000051', '94000000-0000-0000-0000-000000000031', 10),
  ('94000000-0000-0000-0000-000000000062', '94000000-0000-0000-0000-000000000020', '94000000-0000-0000-0000-000000000052', '94000000-0000-0000-0000-000000000032', 10);
insert into stock_lots (id, shop_id, ingredient_id, code, received_at, qty_received, order_line_id) values
  ('94000000-0000-0000-0000-000000000071', '94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000031', 'LOT-A', now(), 10, '94000000-0000-0000-0000-000000000061'),
  ('94000000-0000-0000-0000-000000000072', '94000000-0000-0000-0000-000000000020', '94000000-0000-0000-0000-000000000032', 'LOT-B', now(), 10, '94000000-0000-0000-0000-000000000062');
update purchase_order_lines set lot_id = '94000000-0000-0000-0000-000000000071'
 where id = '94000000-0000-0000-0000-000000000061';
insert into stocktakes (id, shop_id, code, started_by) values
  ('94000000-0000-0000-0000-000000000081', '94000000-0000-0000-0000-000000000010', 'ST-A', '94000000-0000-0000-0000-000000000011'),
  ('94000000-0000-0000-0000-000000000082', '94000000-0000-0000-0000-000000000020', 'ST-B', '94000000-0000-0000-0000-000000000021');
insert into shifts (id, shop_id, opened_by) values
  ('94000000-0000-0000-0000-000000000091', '94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000011'),
  ('94000000-0000-0000-0000-000000000092', '94000000-0000-0000-0000-000000000020', '94000000-0000-0000-0000-000000000021');

do $test$
declare
  v_constraint text;
begin
  insert into stocktake_lines (shop_id, stocktake_id, ingredient_id)
  values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000081', '94000000-0000-0000-0000-000000000031');

  begin
    update ingredients set default_supplier_id = '94000000-0000-0000-0000-000000000042'
     where id = '94000000-0000-0000-0000-000000000031';
    raise exception 'expected default supplier tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'ingredients_default_supplier_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stock_ledger (shop_id, shift_id, ingredient_id, kind, qty_delta)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000092', '94000000-0000-0000-0000-000000000031', 'adjust', 1);
    raise exception 'expected ledger shift tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stock_ledger_shift_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stock_ledger (shop_id, ingredient_id, kind, qty_delta, created_by)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000031', 'adjust', 1, '94000000-0000-0000-0000-000000000021');
    raise exception 'expected ledger actor tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stock_ledger_actor_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stock_ledger (shop_id, ingredient_id, kind, qty_delta)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000032', 'adjust', 1);
    raise exception 'expected ledger ingredient tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stock_ledger_ingredient_same_shop_fk' then raise; end if;
  end;
  begin
    insert into waste_logs (shop_id, shift_id, ingredient_id, qty, reason, entered_by)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000092', '94000000-0000-0000-0000-000000000031', 1, 'test', '94000000-0000-0000-0000-000000000011');
    raise exception 'expected waste shift tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'waste_logs_shift_same_shop_fk' then raise; end if;
  end;
  begin
    insert into waste_logs (shop_id, shift_id, ingredient_id, qty, reason, entered_by)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000091', '94000000-0000-0000-0000-000000000032', 1, 'test', '94000000-0000-0000-0000-000000000011');
    raise exception 'expected waste ingredient tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'waste_logs_ingredient_same_shop_fk' then raise; end if;
  end;
  begin
    insert into waste_logs (shop_id, shift_id, ingredient_id, qty, reason, entered_by)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000091', '94000000-0000-0000-0000-000000000031', 1, 'test', '94000000-0000-0000-0000-000000000021');
    raise exception 'expected waste actor tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'waste_logs_actor_same_shop_fk' then raise; end if;
  end;

  begin
    insert into purchase_orders (shop_id, code, supplier_id)
    values ('94000000-0000-0000-0000-000000000010', 'BAD-SUP', '94000000-0000-0000-0000-000000000042');
    raise exception 'expected supplier tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'purchase_orders_supplier_same_shop_fk' then raise; end if;
  end;
  begin
    insert into purchase_orders (shop_id, code, created_by)
    values ('94000000-0000-0000-0000-000000000010', 'BAD-ACTOR', '94000000-0000-0000-0000-000000000021');
    raise exception 'expected order actor tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'purchase_orders_created_by_same_shop_fk' then raise; end if;
  end;
  begin
    insert into purchase_orders (shop_id, code, confirmed_by)
    values ('94000000-0000-0000-0000-000000000010', 'BAD-CONFIRMER', '94000000-0000-0000-0000-000000000021');
    raise exception 'expected order confirmer tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'purchase_orders_confirmed_by_same_shop_fk' then raise; end if;
  end;
  begin
    insert into purchase_order_lines (shop_id, order_id, ingredient_id, qty)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000052', '94000000-0000-0000-0000-000000000031', 1);
    raise exception 'expected order line parent tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'purchase_order_lines_order_same_shop_fk' then raise; end if;
  end;
  begin
    update purchase_order_lines set lot_id = '94000000-0000-0000-0000-000000000072'
     where id = '94000000-0000-0000-0000-000000000061';
    raise exception 'expected order line lot tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'purchase_order_lines_lot_same_shop_fk' then raise; end if;
  end;
  begin
    insert into purchase_order_lines (shop_id, order_id, ingredient_id, qty)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000051', '94000000-0000-0000-0000-000000000032', 1);
    raise exception 'expected order line ingredient tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'purchase_order_lines_ingredient_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stock_lots (shop_id, ingredient_id, code, received_at, qty_received)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000032', 'BAD-ING', now(), 1);
    raise exception 'expected lot ingredient tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stock_lots_ingredient_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stock_lots (shop_id, ingredient_id, code, received_at, qty_received, order_line_id)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000031', 'BAD-LINE', now(), 1, '94000000-0000-0000-0000-000000000062');
    raise exception 'expected lot order line tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stock_lots_order_line_same_shop_fk' then raise; end if;
  end;
  begin
    insert into ingredient_cost_events (shop_id, ingredient_id, kind)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000032', 'manual');
    raise exception 'expected cost event ingredient tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'ingredient_cost_events_ingredient_same_shop_fk' then raise; end if;
  end;
  begin
    insert into ingredient_cost_events (shop_id, ingredient_id, kind, created_by)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000031', 'manual', '94000000-0000-0000-0000-000000000021');
    raise exception 'expected cost event actor tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'ingredient_cost_events_actor_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stocktakes (shop_id, code, status, started_by, reviewed_by)
    values ('94000000-0000-0000-0000-000000000010', 'BAD-REVIEWER', 'approved', '94000000-0000-0000-0000-000000000011', '94000000-0000-0000-0000-000000000021');
    raise exception 'expected stocktake reviewer tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stocktakes_reviewed_by_same_shop_fk' then raise; end if;
  end;
  begin
    insert into ingredient_cost_events (shop_id, ingredient_id, kind, order_id)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000031', 'purchase', '94000000-0000-0000-0000-000000000052');
    raise exception 'expected cost event order tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'ingredient_cost_events_order_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stocktakes (shop_id, code, started_by)
    values ('94000000-0000-0000-0000-000000000010', 'BAD-START', '94000000-0000-0000-0000-000000000021');
    raise exception 'expected stocktake actor tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stocktakes_started_by_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stocktake_lines (shop_id, stocktake_id, ingredient_id)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000082', '94000000-0000-0000-0000-000000000031');
    raise exception 'expected stocktake line parent tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stocktake_lines_stocktake_same_shop_fk' then raise; end if;
  end;
  begin
    insert into stocktake_lines (shop_id, stocktake_id, ingredient_id)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000081', '94000000-0000-0000-0000-000000000032');
    raise exception 'expected stocktake line ingredient tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'stocktake_lines_ingredient_same_shop_fk' then raise; end if;
  end;
  begin
    insert into inventory_requests (shop_id, kind, ref_id, note, created_by)
    values ('94000000-0000-0000-0000-000000000010', 'purchase', gen_random_uuid(), 'test request', '94000000-0000-0000-0000-000000000021');
    raise exception 'expected inventory request actor tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'inventory_requests_actor_same_shop_fk' then raise; end if;
  end;
  begin
    insert into waste_logs (shop_id, shift_id, ingredient_id, qty, reason, lot_id)
    values ('94000000-0000-0000-0000-000000000010', '94000000-0000-0000-0000-000000000091', '94000000-0000-0000-0000-000000000031', 1, 'test lot reference', '94000000-0000-0000-0000-000000000072');
    raise exception 'expected waste lot tenant FK';
  exception when foreign_key_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint <> 'waste_logs_lot_same_shop_fk' then raise; end if;
  end;

  raise notice 'INVENTORY TENANT CONSTRAINTS: PASS';
end
$test$;

rollback;
