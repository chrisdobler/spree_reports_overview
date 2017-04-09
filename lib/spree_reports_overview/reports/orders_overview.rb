require 'csv'

module SpreeReportsOverview
  module Reports
    class OrdersOverview < SpreeReportsOverview::Reports::Base
      
      attr_accessor :params, :data
      attr_accessor :currencies, :currency, :stores, :store, :group_by_list, :group_by, :states, :state, :shipment_state, :shipment_states,:months, :date_start
      
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

        # shipment states
        @shipment_states = %w{ready shipped}
        @shipment_state = @shipment_states.include?(params[:shipment_state]) ? params[:shipment_state] : "ready"        

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
        
        # if @state == "complete_paid"
        #   date_column = :completed_at
        #   @sales = Spree::Order.complete.where(payment_state: 'paid')
        # elsif @state == "complete"
        #   date_column = :completed_at
        #   @sales = Spree::Order.complete
        # elsif @state == "incomplete"
        #   date_column = :created_at
        #   @sales = Spree::Order.incomplete
        # elsif @state == "canceled"
        #   date_column = :canceled_at
        #   @sales = Spree::Order.where.not(canceled_at: nil)
        # else
        #   date_column = :created_at
        #   @sales = Spree::Order.where(state: @state)
        # end

        # select by shipment state
        
        if @shipment_state == "ready"
          date_column = :completed_at
          @sales = Spree::Order.complete.where(payment_state: 'paid', shipment_state: 'ready')
        elsif @shipment_state == "shipped"
          date_column = :completed_at
          @sales = Spree::Order.complete.where(payment_state: 'paid', shipment_state: 'shipped')
        end


        @sales = @sales.where("#{date_column.to_s} >= ?", @date_start) if @date_start
        @sales = @sales.where(currency: @currency) if @currencies.size > 1
        @sales = @sales.where(store_id: @store) if @stores.size > 2 && @store != "all"        
        @sales = without_excluded_orders(@sales)
        
        
        @sales_count = @sales.count
        @sales_total = @sales.sum(:total)
        @sales_item_total = @sales.sum(:item_total)
        @sales_adjustment_total = @sales.sum(:adjustment_total)
        @sales_shipment_total = @sales.sum(:shipment_total)
        @sales_promo_total = @sales.sum(:promo_total)
        @sales_included_tax_total = @sales.sum(:included_tax_total)
        @sales_item_count_total = @sales.sum(:item_count)

        @sales = @sales.to_a

      end
      
      def build_response

        variants_count = Hash.new
        @variants_totals = Hash.new

        $i = 0
        while $i < @sales_count do
          @sales[$i].line_items.each do |x|
            variants_count[$i] ? "" : variants_count[$i] = Hash.new
            @variants_totals[x.variant_id] ? "" : @variants_totals[x.variant_id] = 0
            @variants_totals[x.variant_id]+= 1
            variants_count[$i][x.variant_id] ? "" : variants_count[$i][x.variant_id] = 0
            variants_count[$i][x.variant_id]= variants_count[$i][x.variant_id] + 1
          end
          $i +=1
        end

        @data = (0..@sales_count-1).map do |k,i|
          {
            order_number: @sales[k].number,
            delivery_date: @sales[k].customer_delivery_date,
            first_name: Spree::Address.find_by_id(@sales[k].ship_address_id) ? Spree::Address.find_by_id(@sales[k].ship_address_id).firstname : "",
            last_name: Spree::Address.find_by_id(@sales[k].ship_address_id) ? Spree::Address.find_by_id(@sales[k].ship_address_id).lastname : "",
            count_40_jolly: variants_count[k][28] ? variants_count[k][28] : "",
            count_40_kumo: variants_count[k][27] ? variants_count[k][27] : "",
            count_40_pacific: variants_count[k][29] ? variants_count[k][29] : "",
            count_60_combo: variants_count[k][41] ? variants_count[k][41] : "",
            count_80_combo: variants_count[k][42] ? variants_count[k][42] : "",
            count_knife: variants_count[k][32] ? variants_count[k][32] : "",
            special_instructions: @sales[k].special_instructions,
          }
        end
      end

      def to_csv
        CSV.generate(headers: true, col_sep: ",") do |csv|
          csv << %w{sep=,}
          # csv << %w{date date_formatted count item_count_total items_per_order avg_total total item_total adjustment_total shipment_total promo_total included_tax_total }
          csv << %w{order_number delivery_date first_name last_name 40_jolly 40_kumo 40_pacific 60_combo 80_combo knife special_instructions }
          @data.each do |item|
            csv << [
              item[:order_number],
              item[:delivery_date],
              item[:first_name],
              item[:last_name],
              item[:count_40_jolly],
              item[:count_40_kumo],
              item[:count_40_pacific],
              item[:count_60_combo],
              item[:count_80_combo],
              item[:count_knife],
              item[:special_instructions]
            ]
          end
          
          csv << [
            "TOTALS",'','','',
            @variants_totals[28],
            @variants_totals[27],
            @variants_totals[29],
            @variants_totals[41],
            @variants_totals[42],
            @variants_totals[32],
          ]
        end
    
      end
      
      def csv_filename
        "orders_per_period_#{@group_by}_#{@months}-months_#{@state}.csv"
      end
      
    end
  end
end