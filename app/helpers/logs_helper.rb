module LogsHelper
  def get_logdata_field(logdata, field)
    return '' unless logdata.present? && field.present?

    begin
      logdata = JSON.parse(logdata)
      return logdata[field]
    rescue => ex
      Rails.logger.error "get_logdata_field(logdata, field) failed: #{ex.message}"
    end

    # failed to parse field from data
    ''
  end

  # given text, return text plus glyph, wrapped in parentheses
  # input:   'Foo'
  # output:  '( Foo v )'
  def download_label(text = nil)
    return "( #{text} #{download_glyph}".html_safe + ' )' unless text.nil?

    '( download csv '.html_safe + download_glyph + ')'
  end

  def download_glyph
    # https://getbootstrap.com/docs/3.3/components/#glyphicons-glyphs
    # which download glyph?
    #   glyphicon glyphicon-download
    # or
    #   glyphicon glyphicon-download-alt
    '<span class="glyphicon glyphicon-download-alt"></span>'.html_safe
  end
end
