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
    
    # Reserves Contributors were copied over when the reserves item was created
    contributors = reserves_item.fetch('contributors', '')
    return contributors if contributors.present?

    # But if no contributors were found, 
    # use the part of the reserves item title after the slash
    item_author = reserves_item.fetch('author', '')
    return item_author

    # STOP HERE - We don't need instance-level data

    # # Do we need to retrieve full instance details? 
    # return item_author unless reserves_item.key?('instance_uuid')
    # instance = Folio::Client.get_instance_by_id(reserves_item['instance_uuid'])
    # return item_author unless instance.present? and instance.key?('contributors')
    #
    # # We will look for either a single primary contributor,
    # # or - if none are primary - we will list all of them.
    # primary_contributor = nil
    # contributor_list = []
    # instance["contributors"].each do |contributor|
    #   next unless contributor.key?('name') and contributor['name'].present?
    #
    #   if contributor["primary"] == true
    #     primary_contributor = contributor["name"]
    #   else
    #     contributor_list << contributor["name"]
    #   end
    # end
    #
    # return primary_contributor if primary_contributor.present?
    # return contributor_list.join("; ") if contributor_list.length > 0
    # # No instance-level contributor found?  Then return author from item-level data
    # return item_author
  end
  
end

