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
    url = reserves_item['uri'] if reserves_item['uri'].present?

    link_to label, url, target: '_blank'
  end
  
  def get_contributor(reserves_item)
    return '' unless reserves_item.present?

    item_author = reserves_item.fetch('author', '')
    return item_author unless reserves_item.key?('instance_uuid')

    instance = Folio::Client.get_instance_by_id(reserves_item['instance_uuid'])
    return item_author unless instance.present? and instance.key?('contributors')

    instance["contributors"].each do |contributor|
      next unless contributor.key?('name') and contributor['name'].present?
      return contributor["name"] if contributor["primary"] == true
    end
    
    # No instance-level primary contributor?  Then return author from item-level data
    return item_author
  end
  
end

