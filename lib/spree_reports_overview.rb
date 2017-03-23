require 'spree_core'
require 'spree_reports'
require 'spree_reports_overview/engine'
require 'spree_reports_overview/reports/base'
require 'spree_reports_overview/reports/orders_overview'

SpreeReports.reports = [
  :orders_by_period,
  :sold_products,
  :orders_overview,
]