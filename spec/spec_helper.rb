
RSpec.shared_context "spec helper" do

  def get(key)
    ::Patreon.get(key)
  end

  def get_patreon_response(filename)
    FileUtils.mkdir_p("#{Rails.root}/tmp/spec") unless Dir.exists?("#{Rails.root}/tmp/spec")
    FileUtils.cp("#{Rails.root}/plugins/discourse-patreon/spec/fixtures/#{filename}", "#{Rails.root}/tmp/spec/#{filename}")
    File.new("#{Rails.root}/tmp/spec/#{filename}").read
  end

end
