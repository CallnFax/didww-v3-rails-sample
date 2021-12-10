# frozen_string_literal: true
class ExportsController < DashboardController
  before_action :assign_params, only: [:create]

  def new
    resource.export_type = export_type
  end

  def create
    if resource.save
      flash[:success] = 'CDR Export was successfully created.'
      redirect_to export_path(resource)
    else
      render :new
    end
  end

  def show
    respond_to do |format|
      format.html
      format.csv do
        io = resource.csv
        filename = [
              'CDR',
              resource.year,
              resource.month.to_s.rjust(2, '0'),
              resource.filters.did_number,
              resource.url.split('/').last
            ].compact.join('-')
        response.headers['X-Accel-Buffering']   = 'no'
        response.headers['Cache-Control']       = 'no-cache'
        response.headers['Content-Type']        = 'text/csv; charset=utf-8'
        response.headers['Content-Disposition'] = %(attachment; filename="#{filename}")
        response.headers['Content-Length']      = io.size
        self.response_body = io.each_chunk
      end
    end
  end

  private

  def initialize_api_config
    super.merge({
      resource_type: :exports,
      decorator_class: ExportDecorator,
    })
  end

  def default_sorting_column
    :created_at
  end

  def default_sorting_direction
    :desc
  end

  def export_type
    params[:export_type]
  end

  def assign_params
    resource.attributes = export_params
    resource.export_type = export_type
    resource.filters = DIDWW::ComplexObject::ExportFilters.new(send("#{export_type}_export_filters"))
  end

  def cdr_out_export_filters
    year, month = resource_params[:period].to_s.split('/')
    day = resource_params[:day]
    filters = {
      year: year,
      month: month,
      'voice_out_trunk.id': resource_params[:voice_out_trunk_id],
    }
    filters.merge!(day: day) unless day.empty?

    filters
  end

  def cdr_in_export_filters
    year, month = resource_params[:period].to_s.split('/')
    {
      year: year,
      month: month,
      did_numbers: resource_params[:did_number],
    }
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def resource_params
    params.require(:export).permit(
      :period,
      :did_number,
      :callback_method,
      :callback_url,
      :export_type,
      :voice_out_trunk_id,
      :day
    )
  end

  def export_params
    attributes_for_save.except(:period, :voice_out_trunk_id, :day)
  end
end
