# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.
require_relative "../../test_helper"
require_relative "../../support/config_writer_examples"
require "y2network/wicked/config_writer"
require "y2network/config"
require "y2network/connection_configs_collection"
require "y2network/interface"
require "y2network/interfaces_collection"
require "y2network/routing"
require "y2network/route"
require "y2network/routing_table"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/ip_config"

RSpec.shared_examples "WickedConfigWriter" do
  subject(:writer) { described_class.new }

  include_examples "ConfigWriter"

  describe "#write" do
    before do
      allow(Yast::Host).to receive(:Write)
      allow(Yast::SCR).to receive(:Write)
    end

    let(:old_config) do
      Y2Network::Config.new(
        interfaces:  Y2Network::InterfacesCollection.new([eth0]),
        connections: Y2Network::ConnectionConfigsCollection.new([old_eth0_conn]),
        source:      :testing
      )
    end

    let(:config) do
      old_config.copy.tap do |cfg|
        cfg.add_or_update_connection_config(eth0_conn)
        cfg.routing = routing
      end
    end
    let(:ip) { Y2Network::ConnectionConfig::IPConfig.new(IPAddr.new("192.168.122.2")) }
    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:old_eth0_conn) { eth0_conn.clone }

    let(:eth0_conn) do
      Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
        conn.interface = "eth0"
        conn.name = "eth0"
        conn.bootproto = :static
        conn.ip = ip
      end
    end
    let(:route) do
      Y2Network::Route.new(
        to:        IPAddr.new("10.0.0.2/8"),
        interface: eth0,
        gateway:   IPAddr.new("192.168.122.1")
      )
    end
    let(:default_route) do
      Y2Network::Route.new(
        gateway:   IPAddr.new("192.168.122.2")
      )
    end
    let(:routing) do
      Y2Network::Routing.new(
        tables: [Y2Network::RoutingTable.new(routes)]
      )
    end

    let(:ifroute_eth0) do
      instance_double(CFA::RoutesFile, save: nil, :routes= => nil)
    end

    let(:routes_file) do
      instance_double(CFA::RoutesFile, save: nil, :routes= => nil)
    end

    let(:routes) { [route, default_route] }

    let(:interfaces_writer) do
      instance_double(Y2Network::ConfigWriters::InterfacesWriter, write: nil)
    end

    before do
      allow(CFA::RoutesFile).to receive(:new)
        .with("/etc/sysconfig/network/ifroute-eth0")
        .and_return(ifroute_eth0)
      allow(CFA::RoutesFile).to receive(:new)
        .with(no_args)
        .and_return(routes_file)
      allow_any_instance_of(Y2Network::Wicked::ConnectionConfigWriter).to receive(:write)
      allow(Y2Network::ConfigWriters::InterfacesWriter).to receive(:new)
        .and_return(interfaces_writer)
    end

    it "saves general routes to main routes file" do
      expect(routes_file).to receive(:routes=).with([default_route])
      expect(routes_file).to receive(:save)
      writer.write(config, only: [:routing, :interfaces])
    end

    it "saves interface specific routes to the ifroute-* file" do
      expect(ifroute_eth0).to receive(:routes=).with([route])
      expect(ifroute_eth0).to receive(:save)
      writer.write(config, only: [:routing, :interfaces])
    end

    context "when there are no general routes" do
      let(:routes) { [route] }

      it "removes the ifroute file" do
        expect(routes_file).to_not receive(:remove)
        expect(routes_file).to receive(:save)
        writer.write(config, only: [:routing, :interfaces])
      end
    end

    context "when there are no routes for an specific interface" do
      let(:routes) { [default_route] }

      it "removes the ifroute file" do
        expect(ifroute_eth0).to receive(:remove)
        writer.write(config, only: [:routing, :connections])
      end
    end

    context "when an interface is deleted" do
      let(:old_config) do
        Y2Network::Config.new(
          dns:        double("dns"),
          interfaces: Y2Network::InterfacesCollection.new([eth0, eth1]),
          source:     :testing
        )
      end
      let(:eth1) { Y2Network::Interface.new("eth1") }
      let(:ifroute_eth1) do
        instance_double(CFA::RoutesFile, save: nil, :routes= => nil)
      end

      before do
        allow(CFA::RoutesFile).to receive(:new)
          .with("/etc/sysconfig/network/ifroute-eth1")
          .and_return(ifroute_eth1)
      end

      it "removes the ifroute file" do
        expect(ifroute_eth1).to receive(:remove)
        writer.write(config, only: [:routing, :connections])
      end
    end

    context "when a connection is deleted" do
      let(:config) do
        old_config.copy.tap do |cfg|
          cfg.interfaces = Y2Network::InterfacesCollection.new([eth0])
          cfg.connections = Y2Network::ConnectionConfigsCollection.new([])
          cfg.source = :testing
        end
      end

      let(:old_config) do
        Y2Network::Config.new(
          interfaces:  Y2Network::InterfacesCollection.new([eth0]),
          connections: Y2Network::ConnectionConfigsCollection.new([eth0_conn]),
          source:      :wicked
        )
      end

      let(:conn_writer) { instance_double(Y2Network::Wicked::ConnectionConfigWriter) }
      let(:ifroute_eth1) do
        instance_double(CFA::RoutesFile, save: nil, :routes= => nil, remove: nil)
      end

      before do
        allow(Y2Network::Wicked::ConnectionConfigWriter).to receive(:new)
          .and_return(conn_writer)
        allow(CFA::RoutesFile).to receive(:new).and_return(ifroute_eth1)
      end

      it "removes the connection" do
        expect(conn_writer).to receive(:remove).with(eth0_conn)
        writer.write(config, old_config, only: [:interfaces, :connections])
      end
    end

    it "writes connections configurations" do
      expect_any_instance_of(Y2Network::Wicked::ConnectionConfigWriter)
        .to receive(:write).with(eth0_conn, old_eth0_conn)
      writer.write(config, old_config, only: [:interfaces, :connections])
    end
  end
end
