module AdminHelper
  def log_file_link(log_file)
    link = link_to log_file, admin_log_file_path(log_file: log_file), class: 'btn-default'
    content_tag(:div, link)
  end

  def recap_staff_link
    if (recap_staff_url = APP_CONFIG['recap_staff_url'])
      return link_to 'ReCAP Staff Interface', recap_staff_url, target: '_blank'
    end

    ''
  end
end
