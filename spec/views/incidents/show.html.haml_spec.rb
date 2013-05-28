require 'spec_helper'

describe "incidents/show" do
  before(:each) do
    @incident = assign(:incident, stub_model(Incident,
      :street => "Street",
      :city => "City",
      :state => "State",
      :coordinates => "",
      :description => "Description"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Street/)
    rendered.should match(/City/)
    rendered.should match(/State/)
    rendered.should match(//)
    rendered.should match(/Description/)
  end
end
