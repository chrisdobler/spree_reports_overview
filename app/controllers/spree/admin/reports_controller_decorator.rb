Spree::Admin::ReportsController.class_eval do

  def order_overview
    @report = SpreeReports::Reports::OrdersOverview.new(params)
    format.html
    format.csv {
      return head :unauthorized unless SpreeReports.csv_export
      send_data @report.to_csv, filename: @report.csv_filename, type: "text/csv"
    }
  end
  
end