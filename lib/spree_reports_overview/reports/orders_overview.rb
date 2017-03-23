module SpreeReportsOverview
  module Reports
    class OrdersOverview < SpreeReportsOverview::Reports::Base
      
      attr_accessor :params, :data
      attr_accessor :currencies, :currency, :stores, :store, :group_by_list, :group_by, :states, :state, :months, :date_start
      
      def initialize(params)
        @params = params
        setup_params
        get_data
        build_response
      end
      
      def setup_params
        @currencies = Spree::Order.select('currency').distinct.map { |c| c.currency }  
        @currency = @currencies.include?(params[:currency]) ? params[:currency] : @currencies.first
        
        @stores = Spree::Store.all.map { |store| [store.name, store.id] }
        @stores << ["all", "all"]
        @store = @stores.map{ |s| s[1].to_s }.include?(params[:store]) ? params[:store] : @stores.first[1]
    
        @group_by_list = [:day, :week, :month, :year]
        @group_by = @group_by_list.include?(params[:group_by].try(:to_sym)) ? params[:group_by].to_sym : :month
    
        # states
        @states = %w{complete_paid complete incomplete cart address delivery payment confirm canceled}
        @state = @states.include?(params[:state]) ? params[:state] : "complete_paid"
        
        # ******************************************************************************************************
        # MONTHS
    
        @months = SpreeReports.report_months.include?(params[:months]) ? params[:months] : SpreeReports.default_months.to_s
        @date_start = (@months != "all") ? (Time.now - (@months.to_i).months) : nil
    
        if @date_start
          if @group_by == :year
            @date_start = @date_start.beginning_of_year
          elsif @group_by == :month
            @date_start = @date_start.beginning_of_month
          elsif @group_by == :week
            @date_start = @date_start.beginning_of_week
          else
            @date_start = @date_start.beginning_of_day
          end
        end
                
      end
      
      def get_data
        
        # select by state
        
        if @state == "complete_paid"
          date_column = :completed_at
          @sales = Spree::Order.complete.where(payment_state: 'paid')
        elsif @state == "complete"
          date_column = :completed_at
          @sales = Spree::Order.complete
        elsif @state == "incomplete"
          date_column = :created_at
          @sales = Spree::Order.incomplete
        elsif @state == "canceled"
          date_column = :canceled_at
          @sales = Spree::Order.where.not(canceled_at: nil)
        else
          date_column = :created_at
          @sales = Spree::Order.where(state: @state)
        end
    
        @sales = @sales.where("#{date_column.to_s} >= ?", @date_start) if @date_start
        @sales = @sales.where(currency: @currency) if @currencies.size > 1
        @sales = @sales.where(store_id: @store) if @stores.size > 2 && @store != "all"        
        @sales = without_excluded_orders(@sales)
        
        # group by

        if @group_by == :year
          @sales = @sales.group_by_year(date_column, time_zone: SpreeReports.time_zone)
        elsif @group_by == :month
          @sales = @sales.group_by_month(date_column, time_zone: SpreeReports.time_zone)
        elsif @group_by == :week
          # %W => week start: monday, %U => week start: sunday
          @sales = @sales.group_by_week(date_column, time_zone: SpreeReports.time_zone)
        else
          @sales = @sales.group_by_day(date_column, time_zone: SpreeReports.time_zone)
        end
        
        @sales_count = @sales.count
        @sales_total = @sales.sum(:total)
        @sales_item_total = @sales.sum(:item_total)
        @sales_adjustment_total = @sales.sum(:adjustment_total)
        @sales_shipment_total = @sales.sum(:shipment_total)
        @sales_promo_total = @sales.sum(:promo_total)
        @sales_included_tax_total = @sales.sum(:included_tax_total)
        @sales_item_count_total = @sales.sum(:item_count)
        
      end
      
      def build_response
        @data = @sales_count.map do |k, v|
          {
            date: k,
            date_formatted: SpreeReports::Helper.date_formatted(k, @group_by),
            count: v,
            total: @sales_total[k].to_f,
            item_total: @sales_item_total[k].to_f,
            avg_total: SpreeReports::Helper.round(SpreeReports::Helper.divide(@sales_total[k].to_f, v)),
            adjustment_total: @sales_adjustment_total[k].to_f,
            shipment_total: @sales_shipment_total[k].to_f,
            promo_total: @sales_promo_total[k].to_f,
            included_tax_total: @sales_included_tax_total[k].to_f,
            item_count_total: @sales_item_count_total[k].to_i,
            items_per_order: SpreeReports::Helper.round(SpreeReports::Helper.divide(@sales_item_count_total[k].to_f, v.to_f))
          }
        end
      end
      
      def to_csv
    
        CSV.generate(headers: true, col_sep: ";") do |csv|
          csv << %w{date date_formatted count item_count_total items_per_order avg_total total item_total adjustment_total shipment_total promo_total included_tax_total }
      
          @data.each do |item|
            csv << [
              item[:date],
              item[:date_formatted],
              item[:count],
              item[:item_count_total],
              item[:items_per_order],
              item[:avg_total],
              item[:total],
              item[:item_total],
              item[:adjustment_total],
              item[:shipment_total],
              item[:promo_total],
              item[:included_tax_total]
            ]
          end
      
        end
    
      end
      
      def csv_filename
        "orders_per_period_#{@group_by}_#{@months}-months_#{@state}.csv"
      end
      
    end
  end
end