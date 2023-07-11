module "lots_of_vars" {
  source = "github.com/infralight/hcl-indexing-test-repo//modules/lots_of_vars"

  number_without_default      = 24323
  with_description_no_default = "bibi"
  with_validation             = "eran6654"
  nullable_string             = "lev"
  with_ugly_validation        = "LAG"
}
