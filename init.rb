require 'redmine'

Time::DATE_FORMATS[:week] = "%Y %b %e"
Time::DATE_FORMATS[:param_date] = "%Y-%m-%d"
Time::DATE_FORMATS[:day] = "%a %e"
Time::DATE_FORMATS[:day_full] = "%Y %b %e, %A"
Time::DATE_FORMATS[:database] = "%a, %d %b %Y"

Rails.configuration.to_prepare do
  TimeEntry.class_eval do
    named_scope :for_user, lambda { |user| {:conditions => "#{TimeEntry.table_name}.user_id = #{user.id}"}}
    named_scope :spent_on, lambda { |date| {:conditions => ["#{TimeEntry.table_name}.spent_on = ?", date]}}
  end
end


Redmine::Plugin.register :redmine_hours do
  name 'Redmine Hours Plugin'
  author 'Digital Natives'
  description 'Redmine Hours is a plugin to fill out your weekly timelog / timesheet easier.'
  version '0.1.0'
  url 'https://github.com/digitalnatives/redmine_hours'

	project_module :hours do
  	permission :view_hours, :work_time => :index
	end

	menu(:top_menu, :hours, {:controller => "hours", :action => 'index'}, :caption => 'Hours', :after => :my_page, :if => Proc.new{ User.current.logged? }, :param => :user_id)

end
