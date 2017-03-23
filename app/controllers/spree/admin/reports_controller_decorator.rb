require 'spree_reports'

Spree::Admin::ReportsController.class_eval do

  def orders_overview
    @report = SpreeReportsOverview::Reports::OrdersOverview.new(params)
    format.html
    format.csv {
      return head :unauthorized unless SpreeReports.csv_export
      send_data @report.to_csv, filename: @report.csv_filename, type: "text/csv"
    }
  end  
  
end