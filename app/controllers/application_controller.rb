class ApplicationController < ActionController::Base
  before_filter :set_access_control_headers

   def set_access_control_headers
   headers['Access-Control-Allow-Origin'] = '*'
   headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET, OPTIONS'
   headers['Access-Control-Request-Method'] = '*'
   headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
  end

  def geocode
    if params[:address].present?
      result = Geocoder.search(params[:address])
    else
      result = Geocoder.search([params[:lat], params[:long]])
    end
    unless result.blank?
      result = result.first.data    
    latitude = result["geometry"]["location"]["lat"]
    longitude = result["geometry"]["location"]["lng"]
    address_components = result["address_components"]
    fields_to_get = {"street_number" => "long_name", "route" => "long_name", "locality" => "long_name", "administrative_area_level_1" => "short_name", "postal_code" => "long_name"}
    full_address={}
    address_components.each do |ac|
      fields_to_get.each do |k, v|
        full_address[k] = ac[v] if ac["types"].include?(k)
      end
    end
    address = full_address["street_number"].to_s + " " + full_address["route"].to_s
    city = full_address["locality"]
    state = full_address["administrative_area_level_1"]
    zip = full_address["postal_code"]
    formatted_address = result["formatted_address"]
    if params.keys.include? "uuid"
     [city,state,zip,formatted_address,address]
    else
     render :text => "{\"latitude\":#{latitude}, \"longitude\":#{longitude}, \"address\":\"#{address}\", \"city\":\"#{city}\",\"state\":\"#{state}\",\"zip\":\"#{zip}\",\"formatted_address\":\"#{formatted_address}\"}"
   end
   else
     ["500"]
   end
   end

  def company_location
    redirect_to geocode_url(:address => Company.first.location)
  end


  def distance_between(point_a, point_b)
 Photo.create(
        :photo_name => params[:photo_name],
        :photo_thumbnail_name => params[:photo_thumbnail_name],
        :source_entity => params[:source_entity],
        :entity_id => params[:entity_id]
    )   
 Geocoder::Calculations.distance_between(
        [point_a.geo_lat, point_a.geo_long],
        [point_b.geo_lat, point_b.geo_long]
    ).round(2)
  end

  def upload_status
    render :text => REDIS.get("#{params[:id]}:status")
  end

  def store_photo
    Photo.create(
        :photo_name => params[:photo_name],
        :photo_thumbnail_name => params[:photo_thumbnail_name],
        :source_entity => params[:source_entity],
        :entity_id => params[:entity_id]
    )
     if params.keys.include?"uuid"
      render :json=>{:status_code=>200,:message=>"success"}
     else
      render :text => "Ok"
     end
    end

  def show_photos
    photos = []
    @photos = Photo.where(:entity_id => params[:id]).order(:id)
    @photos.each do |current_photo|
      photo = []
      photo.push("\"photo_id\":\"#{current_photo.id}\"")
      photo.push("\"photo_name\":\"#{current_photo.photo_name}\"")
      photo.push("\"photo_thumbnail_name\":\"#{current_photo.photo_thumbnail_name}\"")
      photos.push("{" + photo.join(",") + "}")
    end
    render :text => "[" + photos.join(",") + "]"
  end

  def delete_photo
    Photo.delete(params[:id])
    render :text => "Ok"
  end

  def store_document
    Document.create(
        :document_name => params[:document_name],
        :document_thumbnail_name => params[:document_thumbnail_name],
        :source_entity => params[:source_entity],
        :entity_id => params[:entity_id]
    )
    render :text => "Ok"
  end

  def show_documents
    documents = []
    @documents = Document.where(:entity_id => params[:id]).order(:id)
    @documents.each do |current_document|
      document = []
      document.push("\"document_id\":\"#{current_document.id}\"")
      document.push("\"document_name\":\"#{current_document.document_name}\"")
      document.push("\"document_thumbnail_name\":\"#{current_document.document_thumbnail_name}\"")
      documents.push("{" + document.join(",") + "}")
    end
    render :text => "[" + documents.join(",") + "]"
  end

  def delete_document
    Photo.delete(params[:id])
    render :text => "Ok"
  end
  
  #Check  the token for file_upload token exists, create the new token
   def generate_new_token
	begin
       inventory_token = SecureRandom.urlsafe_base64
      end while CheckInventory.exists?(:check_inventory_token => inventory_token)   
	  return inventory_token
  end
  
  
    # Check  the token.If token exists, create the new token
  def inventory_token
     inventory_token = generate_new_token
     render :json=>{:status=>200,:inventory_token=>inventory_token}
   end

  
  private

  def current_user
    unless params[:uuid]
    token = params[:auth_token].present? ? params[:auth_token] : cookies[:auth_token]
    @current_user ||= User.find_by_auth_token(token) if token
    else
      @current_user ||= User.find_by_u_uid(params[:uuid]) if params[:uuid]
    end
  end 

  helper_method :current_user

  def store_location
    session[:return_to] = request.fullpath if request.get? and controller_name != "user_sessions" and controller_name != "sessions"
  end

  def redirect_back_or_default(default, flash = nil)
    Rails.logger.info "Redirect requested to #{session[:return_to]}"
    if session[:return_to].nil?
      Rails.logger.info "Redirecting to root instead"
      redirect_to root_url
    else
      redirect_to(session[:return_to], :flash => flash || default)
    end
  end

  def authorize
    store_location
    if current_user.nil?
     if params.keys.include?"uuid"
       render :json=>{:status_code=>401, :message=>"Authorization failed"}
     else
      redirect_to login_url 
     end
     end
  end

  rescue_from CanCan::AccessDenied do |exception|
    flash[:error] = "Access denied."
    redirect_to root_url
  end
end
