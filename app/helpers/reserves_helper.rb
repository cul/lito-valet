module ReservesHelper
  
  # On the course-selection form, link course-number to that course's reserves list
  def course_reserves_link(course)
    label = course["course_number"]
    url   = course_reserves_path( course["course_number"] )
    if course["reserves_count"] > 0
      link_to label, url
    else
      label
    end
  end
  
  # On a list of course reserves, link the call-number to the CLIO page for that title
  def reserve_item_link(reserves_item)
    label = reserves_item["call_number"]
    url   = "https://clio.columbia.edu/catalog/" + reserves_item["instance_hrid"]
    link_to label, url, target: '_blank'
  end
  
  
end

