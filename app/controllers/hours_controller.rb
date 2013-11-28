class HoursController < ApplicationController
  unloadable

  before_filter :get_user
  before_filter :get_dates
  before_filter :get_issues

  def index
  end

  def next
    if @current_day
      redirect_to :action => 'index', :day => (@current_day + 1).to_s(:param_date)
    else
      redirect_to :action => 'index', :week => (@week_start + 7).to_s(:param_date)
    end
  end

  def prev
    if @current_day
      redirect_to :action => 'index', :day => (@current_day - 1).to_s(:param_date)
    else
      redirect_to :action => 'index', :week => (@week_start - 7).to_s(:param_date)
    end
  end

  def save_weekly
    params['hours'].each do |day, issue_hash|
      issue_hash.each do |issue_id, activity_hash|
        activity_hash.each do |activity_id, hours|
          if issue_id =~ /no_issue/
            TimeEntry.find_or_create_by_user_id_and_project_id_and_issue_id_and_activity_id_and_spent_on(@user.id,
                                                                                        issue_id.split(":").last.to_i,
                                                                                        nil,
                                                                                        activity_id.to_i,
                                                                                        day).update_attributes(:hours => hours.to_f) unless hours.blank?
          else
            TimeEntry.find_or_create_by_user_id_and_issue_id_and_activity_id_and_spent_on(@user.id,
                                                                                        issue_id.to_i,
                                                                                        activity_id.to_i,
                                                                                        day).update_attributes(:hours => hours.to_f) unless hours.blank?
          end
        end
      end
    end
    redirect_to :back
  end

  def save_daily
    params['hours'].each { |te_id, hash| TimeEntry.find(te_id.to_i).update_attributes(:hours => hash['spent'].to_f, :comments => hash['comments']) }
    redirect_to :back
  end

  def delete_row
    TimeEntry.for_user(@user).spent_between(@week_start, @week_end).find(:all, :conditions => ["issue_id = \"#{params[:issue_id]}\" AND activity_id = \"#{params[:activity_id]}\" "]).each(&:delete)
    TimeEntry.for_user(@user).spent_between(@week_start, @week_end).find(:all, :conditions => ["project_id = \"#{params[:project_id]}\" AND issue_id IS NULL AND activity_id = \"#{params[:activity_id]}\" "]).each(&:delete)
    redirect_to :back
  end

  private

  def get_dates
    @current_day = DateTime.strptime(params[:day], Time::DATE_FORMATS[:param_date]) rescue nil
    if @current_day
      @week_start = @current_day.beginning_of_week
      @week_end = @current_day.end_of_week
    else
      @week_start = params[:week].nil? ? DateTime.now.beginning_of_week : DateTime.strptime(params[:week], Time::DATE_FORMATS[:param_date]).beginning_of_week
      @week_end = params[:week].nil? ? DateTime.now.end_of_week : DateTime.strptime(params[:week], Time::DATE_FORMATS[:param_date]).end_of_week
    end
  end

  def get_issues
    @loggable_projects = Project.all.select{ |pr| @user.allowed_to?(:log_time, pr)}

    weekly_time_entries = TimeEntry.for_user(@user).spent_between(@week_start, @week_end)

    @week_issue_matrix = {}
    weekly_time_entries.each do |te|
      key = te.project.name + (te.issue ? " - #{te.issue.subject}" : "") +  " - #{te.activity.name}"
      @week_issue_matrix[key] ||= {:issue_id => te.issue_id,
                                                                                                      :activity_id => te.activity_id,
                                                                                                      :project_id => te.project.id,
                                                                                                      :project_name => te.project.name,
                                                                                                      :issue_text => te.issue.try(:to_s),
                                                                                                      :activity_name => te.activity.name
                                                                                                     }
      @week_issue_matrix[key][:issue_class] ||= te.issue.closed? ? 'issue closed' : 'issue' if te.issue
      @week_issue_matrix[key][te.spent_on.to_s(:param_date)] = {:hours => te.hours, :te_id => te.id, :comments => te.comments}
    end

    @week_issue_matrix = @week_issue_matrix.sort
    @daily_totals = {}

    (@week_start..@week_end).each do |day|
      @daily_totals[day.to_s(:param_date)] = TimeEntry.for_user(@user).spent_on(day.to_s(:param_date)).map(&:hours).inject(:+)
    end

    @daily_issues = @week_issue_matrix.select{|k,v| v[@current_day.to_s(:param_date)]} if @current_day

    if @week_issue_matrix.empty?
      @week_issue_matrix = {}
      last_week_time_entries = TimeEntry.for_user(@user).spent_between(@week_start-7, @week_end-7).sort_by{|te| te.issue.project.name}.sort_by{|te| te.issue.subject }
      last_week_time_entries.each do |te|
        @week_issue_matrix["#{te.issue.project.name} - #{te.issue.subject} - #{te.activity.name}"] ||= {:issue_id => te.issue_id,
                                                                                                      :activity_id => te.activity_id,
                                                                                                      :project_id => te.issue.project.id,
                                                                                                      :project_name => te.issue.project.name,
                                                                                                      :issue_text => te.issue.to_s,
                                                                                                      :activity_name => te.activity.name
                                                                                                     }
        @week_issue_matrix["#{te.issue.project.name} - #{te.issue.subject} - #{te.activity.name}"][:issue_class] ||= te.issue.closed? ? 'issue closed' : 'issue'
      end
      @week_issue_matrix = @week_issue_matrix.sort
    end

    logger.debug '+++++++++++++++++++++++++++++++++++'
    logger.debug @week_issue_matrix.inspect
    logger.debug '+++++++++++++++++++++++++++++++++++'
  end

  def get_user
    render_403 unless User.current.logged?

    if params[:user_id] && params[:user_id] != User.current.id.to_s
      if User.current.admin?
        @user = User.find(params[:user_id])
      else
        render_403
      end
    else
      @user = User.current
    end
  end

end
