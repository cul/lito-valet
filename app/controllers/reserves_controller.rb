class ReservesController < ApplicationController

  # CU login required for any access to course reserves
  before_action :authenticate_user!

  # Our index is a simple static course reserves search page
  def index
  end

  # Catch posted key/value query params, redirect as positional path params
  # (forms submit as course_number=20251MGMT8531B001, redirect to .../course/20251MGMT8531B001 )
  def course_redirect
    course_number = params[:course_number]
    if course_number.empty?
      redirect_to reserves_path and return
    end
    
    redirect_to course_reserves_path(course_number: course_number) 
  end

  # Display the course reserves list for a specific course number
  def course
    # The course number should look like:  20251MGMT8531B001
    @course_number = params[:course_number]

    # Detect and correct variant course-number formats
    @course_number = normalize_course_number(@course_number)

    # We may manipulate this to run a query, 
    # but want to preseve the original value for display
    course_number_query = @course_number.dup
    
    # If the supplied course number is too short, 
    # change it to a wild-card search
    if course_number_query.length < 17
      course_number_query = '*' + course_number_query + '*'
    end
    
    @okapi_client ||= Folio::OkapiClient.new
    
    folio_courses_list = @okapi_client.get_courses_list_by_course_number(course_number_query)
    
    # If the course-number lookup for no matching course,
    # return to the index page
    if folio_courses_list.size == 0
      error_message = "No courses found matching: " + @course_number
      redirect_to reserves_path, error: error_message
      return
    end
    
    # If more than one course matched the course-number lookup, 
    # ask the user to disambiguate
    if folio_courses_list.size > 1
      @simple_courses_list = parse_folio_courses_list(folio_courses_list)
      render 'course_selection'
      return
    end
    
    # If only a single FOLIO course was returned matching the submitted course number,
    # lookup the reserves for that course.
    course_listing_id = folio_courses_list.first["courseListingId"]
    folio_reserves_list = @okapi_client.get_reserves_list_by_course_listing_id(course_listing_id)
    
    # Simlify the complex FOLIO JSON response object into a simple list of elements for display
    @simple_reserves_list = parse_folio_reserves_list(folio_reserves_list)
  end
  
  private
  
  def normalize_course_number(course_number)
    course_number = course_number.upcase.strip

    # LDAP Affil formatted course numbers
    #   Does it look like this?  ENGLC1010_518_2024_3
    #   We want:                 20243ENGL1010C518
    ldap_format = /([A-Z]{4})([A-Z])(\d\d\d\d)_(\d\d\d)_(20\d\d)_(\d)/
    if match = course_number.match(ldap_format)
      department  = match[1]
      code        = match[2]
      course      = match[3]
      section     = match[4]
      year        = match[5]
      semester    = match[6]
      return year + semester + department + course + code + section
    end
    
    # No other known-cases for reformatting?  Return what we've got.
    return course_number
  end
  

  # Parse the complex nested FOLIO JSON course list into simple array of hashes
  def parse_folio_courses_list(folio_courses_list)
    simple_courses_list = []
    
    folio_courses_list.each do |folio_course|

      # Clean up complex FOLIO data as needed
      instructor_names = parse_folio_instructor_objects( folio_course["courseListingObject"]["instructorObjects"] )
      # FOLIO reserves lists include multiple copies - we need to consolidate
      folio_reserves_list = @okapi_client.get_reserves_list_by_course_listing_id(folio_course["courseListingId"])
      reserves_count = parse_folio_reserves_list(folio_reserves_list).size

      simple_course = {}
      
      simple_course["name"]            = folio_course["name"]
      simple_course["instructor"]      = instructor_names
      simple_course["course_number"]   = folio_course["courseNumber"]
      simple_course["reserves_count"]  = reserves_count
      
      simple_courses_list << simple_course
    end
    
    return simple_courses_list
  end
  
  # A course with multiple instructors is returned in a complex object,
  # which needs to be parsed into a simple string for display
  def parse_folio_instructor_objects(folio_instructor_objects)
    instructor_names = []
    folio_instructor_objects.each do |instructor_object|
      instructor_names << instructor_object['name']
    end
    return instructor_names.join(', ')
  end
  
  
  # Parse the complex nested FOLIO JSON reserves list into simple array of hashes
  def parse_folio_reserves_list(folio_reserves_list)
    simple_reserves_list = []
    
    folio_reserves_list.each do |folio_reserves_item|

      # When there are multiple copies of a title in the catalog, 
      # FOLIO will return that item multiple times in the API response.
      # Don't re-add an item if we alredy have it.
      next if simple_reserves_list.any? do |simple_reserves_item|  
        simple_reserves_item["instance_hrid"] == folio_reserves_item["copiedItem"]["instanceHrid"]
      end
      
      simple_reserves_item = {}
      
      simple_reserves_item["title"]          = folio_reserves_item["copiedItem"]["title"]
      simple_reserves_item["call_number"]    = folio_reserves_item["copiedItem"]["callNumber"]
      simple_reserves_item["instance_hrid"]  = folio_reserves_item["copiedItem"]["instanceHrid"]
      
      simple_reserves_list << simple_reserves_item
    end
    
    return simple_reserves_list
  end
  

end
