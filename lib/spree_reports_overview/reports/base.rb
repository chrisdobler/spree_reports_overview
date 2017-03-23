module SpreeReportsOverview
  module Reports
    class Base
      
      def excluded_user_ids
        users = []
        if SpreeReports.excluded_roles && SpreeReports.excluded_roles.any?
          users += Spree::User.joins(:spree_roles).where("spree_roles.name": SpreeReports.excluded_roles).pluck(:id)
        end

        if SpreeReports.excluded_users && SpreeReports.excluded_users.any?
          users += Spree::User.where(email: SpreeReports.excluded_users).pluck(:id)
        end
        
        users.uniq
      end
      
      def without_excluded_orders(orders)
        return orders if excluded_user_ids.none?
        excluded_order_ids = Spree::Order.where(user_id: excluded_user_ids).pluck(:id)
        orders.where.not(id: excluded_order_ids) if excluded_order_ids.any?  
      end
        
    end
  end
end




