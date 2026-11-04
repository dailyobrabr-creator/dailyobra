-- Banner de campanha da loja, mostrado na página dela abaixo dos dados. É separado da capa porque o banner tem texto e
-- datas, e o recorte da capa cortaria a campanha. Quem grava é o dono ou o gerente, pela mesma regra dos outros dados da loja.

alter table public.lojas add column banner_path text check (char_length(banner_path) <= 500);
