-- package.loaded["integration_test"] = nil
local test = require "integration_test"
local capabilities = require "st.capabilities"
local data_types = require "st.zigbee.data_types"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"
local t_utils = require "integration_test.utils"

local mock_parent_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("colordimmer_v1.yaml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "mfr",
      model = "mdl",
      server_clusters = { 0x0000, 0x0006, 0x0008, 0x0300 },
      client_clusters = { }
    },
    [2] = {
      id = 2,
      manufacturer = "child_mfr",
      model = "child_mdl",
      server_clusters = { 0x0006, 0x0008, 0x0300 },
      client_clusters = { }
    },
  },
  fingerprinted_endpoint_id = 0x01
})

local mock_first_child = test.mock_device.build_test_child_device({
  profile = t_utils.get_profile_definition("child_colordimmer_v1.yaml"),
  parent_device_id = mock_parent_device.id,
  parent_assigned_child_key = string.format("%02X", 2)
})

local test_init = function ()
  test.mock_device.add_test_device(mock_parent_device)
  test.mock_device.add_test_device(mock_first_child)
end

test.register_coroutine_test("device_lifecycle added", function ()
  -- mock_parent_device:expect_metadata_update({profile="switch_v1"})
  mock_parent_device:expect_device_create({
    type = "EDGE_CHILD",
    -- device_network_id = nil,
    parent_assigned_child_key = "02",
    label = "Child 2",
    profile = "child_colordimmer_v1",
    parent_device_id = mock_parent_device.id,
    manufacturer = "default-clusters",
    model = "child_colordimmer_v1",
    -- vendor_provided_label = "Child 2",
  })

  test.socket.device_lifecycle:__queue_receive({ mock_parent_device.id, "added" })

  test.timer.__create_and_queue_test_time_advance_timer(0, "oneshot")
  test.socket.zigbee:__expect_send({ mock_parent_device.id, zigbee_test_utils.build_attribute_read(mock_parent_device, zcl_clusters.Basic.ID, { 0x0004, 0x0000, 0x0001, 0x0005, 0x0007, 0xFFFE }):to_endpoint(0x01) })
  test.socket.capability:__expect_send(mock_parent_device:generate_test_message("main", capabilities["valleyboard16460.info"].value("<table style=\"font-size:0.6em;min-width:100%\"><tbody>\n        <tr><th align=\"left\" style=\"width:40%\">Manufacturer</th><td colspan=\"2\" style=\"width:60%\">mfr</td></tr>\n        <tr><th align=\"left\">Model</th><td colspan=\"2\">mdl</td></tr>\n        <tr><th align=\"left\">Endpoint</th><td colspan=\"2\">0x01</td></tr>\n        <tr><th align=\"left\">Device ID</th><td colspan=\"2\">0x0000</td></tr>\n        <tr><th align=\"left\">Profile ID</th><td colspan=\"2\">0x0000</td></tr>\n        <tr><th colspan=\"3\">Server Clusters</th></tr>\n        <tr><th align=\"left\">Basic</th><td>0x0000</td><td>0x01</td></tr><tr><th align=\"left\">ColorControl</th><td>0x0300</td><td>0x01, 0x02</td></tr><tr><th align=\"left\">OnOff</th><td>0x0006</td><td>0x01, 0x02</td></tr><tr><th align=\"left\">Level</th><td>0x0008</td><td>0x01, 0x02</td></tr>\n        <tr><th colspan=\"3\">Client Clusters</th></tr>\n        <tr><td colspan=\"3\">None</td></tr>\n      </tbody></table>")))

  test.socket.device_lifecycle:__queue_receive({ mock_parent_device.id, "init" })
end, {
  test_init = function()
    test.mock_device.add_test_device(mock_parent_device)
  end
})

test.register_message_test(
  "From zigbee (on)",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_parent_device.id, zcl_clusters.OnOff.attributes.OnOff:build_test_attr_report(mock_parent_device,
          true):from_endpoint(0x01) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_parent_device:generate_test_message("main",  capabilities.switch.switch.on())
    },
  }, {
    test_init = test_init
  }
)

test.register_message_test(
  "To zigbee (on)",
  {
    {
      channel = "capability",
      direction = "receive",
      message = { mock_parent_device.id, { capability = "switch", component = "main", command = "on", args = {} } },
    },
    {
      channel = "zigbee",
      direction = "send",
      message = { mock_parent_device.id, zcl_clusters.OnOff.commands.On(mock_parent_device) }
    },
  }, {
    test_init = test_init
  }
)

test.register_message_test(
  "From zigbee (off)",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_parent_device.id, zcl_clusters.OnOff.attributes.OnOff:build_test_attr_report(mock_parent_device,
          false):from_endpoint(0x02) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_first_child:generate_test_message("main", capabilities.switch.switch.off())
    },
  }, {
    test_init = test_init
  }
)

test.register_message_test(
  "To zigbee (off)",
  {
    {
      channel = "capability",
      direction = "receive",
      message = { mock_first_child.id, { capability = "switch", component = "main", command = "off", args = {} } },
    },
    {
      channel = "zigbee",
      direction = "send",
      message = { mock_parent_device.id, zcl_clusters.OnOff.commands.Off(mock_parent_device):to_endpoint(0x02) }
    },
  }, {
    test_init = test_init
  }
)

test.register_message_test(
  "From zigbee (10%)",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_parent_device.id, zcl_clusters.Level.attributes.CurrentLevel:build_test_attr_report(mock_parent_device,
          0x19):from_endpoint(0x02) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_first_child:generate_test_message("main", capabilities.switchLevel.level(10))
    },
  }, {
    test_init = test_init
  }
)

test.register_message_test(
  "To zigbee (73%)",
  {
    {
      channel = "capability",
      direction = "receive",
      message = { mock_first_child.id, { capability = "switchLevel", component = "main", command = "setLevel", args = {0x1D} } },
    },
    {
      channel = "zigbee",
      direction = "send",
      message = { mock_parent_device.id, zcl_clusters.Level.commands.MoveToLevelWithOnOff(mock_parent_device, 73, 0xFFFF):to_endpoint(0x02) }
    },
  }, {
    test_init = test_init
  }
)

test.register_message_test(
  "From zigbee (hue=100)",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_parent_device.id, zcl_clusters.ColorControl.attributes.CurrentHue:build_test_attr_report(mock_parent_device,
          0xFF):from_endpoint(0x02) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_first_child:generate_test_message("main", capabilities.colorControl.hue(100))
    },
  }, {
    test_init = test_init
  }
)

test.register_message_test(
  "To zigbee (hue=0,sat=100)",
  {
    {
      channel = "capability",
      direction = "receive",
      message = { mock_first_child.id, { capability = "colorControl", component = "main", command = "setColor", args = { {hue=0,saturation=100} } } },
    },
    {
      channel = "zigbee",
      direction = "send",
      message = { mock_parent_device.id, zcl_clusters.OnOff.commands.On(mock_parent_device):to_endpoint(0x02) }
    },
    {
      channel = "zigbee",
      direction = "send",
      message = { mock_parent_device.id, zcl_clusters.ColorControl.commands.MoveToHueAndSaturation(mock_parent_device, 0x00, 0xFE):to_endpoint(0x02) }
    },
  }, {
    test_init = test_init
  }
)