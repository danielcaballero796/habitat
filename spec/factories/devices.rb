FactoryBot.define do
  factory :device do
    name { "Test Device" }
    type { :smart_plug }
    brand { "TP-Link" }
    model { "Tapo P115" }
    room { "Kitchen" }
    status { "online" }
    ip_address { "192.168.1.100" }
    mac_address { "AA:BB:CC:DD:EE:FF" }
    firmware_version { "1.2.4" }
    purchase_date { Date.today }
    notes { "Test device" }
  end

  factory :device_attribute do
    device
    key { "power_w" }
    value { "12.5" }
  end
end
