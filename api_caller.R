library(plumber)

pr("api_generator.R") %>%
  pr_run(port=8000)

# USE THIS LINK TO TEST: http://localhost:8000/predict?char_age=112&char_air=2&char_apts=6&char_attic_fnsh=1&char_attic_type=2&char_beds=4&char_bldg_sf=2000&char_bsmt=1&char_bsmt_fin=3&char_ext_wall=1&char_fbath=2&char_frpl=1&char_gar1_area=2&char_gar1_att=2&char_gar1_cnst=1&char_gar1_size=3&char_hbath=0&char_hd_sf=12012&char_heat=1&char_oheat=5&char_porch=1&char_roof_cnst=1&char_rooms=7&char_tp_dsgn=2&char_tp_plan=2&char_type_resd=2&char_use=1&econ_midincome=148670&econ_tax_rate=7.216&geo_floodplain=0&geo_fs_flood_factor=1&geo_fs_flood_risk_direction=0&geo_ohare_noise=0&geo_school_elem_district=COMMUNITY%20UNIT%20SCHOOL%20DISTRICT%20220&geo_school_hs_district=COMMUNITY%20UNIT%20SCHOOL%20DISTRICT%20220&geo_withinmr100=0&geo_withinmr101300=0&ind_garage=TRUE&ind_large_home=FALSE&meta_nbhd=10012&meta_sale_price=307500&meta_town_code=10&time_sale_day_of_year=290&time_sale_during_holidays=FALSE&time_sale_during_school_year=TRUE&time_sale_month_of_year=10&time_sale_quarter_of_year=Q4&time_sale_week=1241&time_sale_week_of_year=42

# NOTE: Explanation about the variables and valid inputs can be found at ccao::vars_dict.