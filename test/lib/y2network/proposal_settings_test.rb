#!/usr/bin/env rspec

require_relative "../../test_helper"
require "y2network/proposal_settings"

describe Y2Network::ProposalSettings do
  subject { described_class.create_instance }
  let(:nm_available) { true }
  let(:feature) { { "network" => { "network_manager" => "always" } } }

  before do
    allow_any_instance_of(Y2Network::ProposalSettings)
      .to receive(:network_manager_available?).and_return(nm_available)
    stub_features(feature)
  end

  def stub_features(features)
    Yast.import "ProductFeatures"
    Yast::ProductFeatures.Import(features)
  end

  def expect_backend(name)
    case name
    when :network_manager
      expect_any_instance_of(described_class)
        .to receive(:enable_network_manager!).and_call_original
      expect(created_instance.backend).to eql(:network_manager)
    else
      expect_any_instance_of(described_class)
        .to receive(:enable_wicked!).and_call_original
      expect(created_instance.backend).to eql(:wicked)
    end
  end

  describe ".instance" do
    context "no instance has been created yet" do
      before do
        described_class.instance_variable_set("@instance", nil)
      end

      it "creates a new instance" do
        expect(described_class).to receive(:new).and_call_original
        described_class.instance
      end
    end

    context "when a instance has been already created" do
      before do
        described_class.instance
      end

      it "does not create any new instance" do
        expect(described_class).to_not receive(:new)
        described_class.instance
      end

      it "returns the existent instance" do
        instance = described_class.instance
        expect(instance.object_id).to eql(described_class.instance.object_id)
      end
    end
  end

  describe ".create_instance" do
    let(:created_instance) { described_class.create_instance }
    let(:logger) { double(info: true) }
    let(:nm_available) { false }

    it "creates a new network proposal settings instance" do
      instance = described_class.instance
      expect(created_instance).to be_a(described_class)
      expect(created_instance).to_not equal(instance)
    end

    context "when the NetworkManager package is not available" do
      it "enables :wicked as the default backend" do
        expect_any_instance_of(described_class)
          .to receive(:enable_wicked!).and_call_original
        expect(created_instance.backend).to eql(:wicked)
      end
    end

    context "when the NetworkManager package is available" do
      let(:nm_available) { true }

      context "and the ProductFeature .network.network_manager is not defined" do
        context "and neither .network.network_manager_is_default is" do
          let(:feature) { { "network" => {} } }

          it "enables :wicked as the default backend" do
            expect_backend(:wicked)
          end
        end

        context "but .network.network_manager_is_default is" do
          let(:feature) { { "network" => { "network_manager_is_default" => true } } }

          it "enables :network_manager as the default backend" do
            expect_backend(:network_manager)
          end
        end
      end

      context "and the ProductFeature .network.network_manager is 'always'" do
        it "enables :network_manager as the default backend" do
          expect_backend(:network_manager)
        end
      end

      context "and the ProductFeature .network.network_manager is 'laptop'" do
        let(:is_laptop) { true }
        let(:feature) { { "network" => { "network_manager" => "laptop" } } }

        before do
          allow(Yast::Arch).to receive(:is_laptop).and_return(is_laptop)
        end

        context "and the machine is a laptop" do
          it "enables :network_manager as the backend to be used" do
            expect_backend(:network_manager)
          end
        end

        context "and the machine is not a laptop" do
          let(:is_laptop) { false }
          it "enables :wicked as the backend to be used" do
            expect_backend(:wicked)
          end
        end
      end

      it "initializes the default network backend from the product control file" do
        expect(described_class.create_instance.backend).to eql(:network_manager)
        stub_features("network" => { "network_manager" => "" })
        expect(described_class.create_instance.backend).to eql(:wicked)
      end
    end

    it "logs which backend has been selected as the default" do
      allow_any_instance_of(described_class).to receive(:log).and_return(logger)
      expect(logger).to receive(:info).with(/backend is: wicked/)
      described_class.create_instance
    end
  end

  describe "#enable_wicked!" do
    before do
      subject
    end

    it "adds the wicked package to the list of resolvables " do
      expect(Yast::PackagesProposal).to receive(:AddResolvables)
        .with("network", :package, ["wicked"])
      subject.enable_wicked!
    end

    it "removes the NetworkManager package from the list of resolvables " do
      expect(Yast::PackagesProposal).to receive(:RemoveResolvables)
        .with("network", :package, ["NetworkManager"])
      subject.enable_wicked!
    end

    it "sets :wicked as the backend" do
      expect(subject.backend).to eql(:network_manager)
    end
  end

  describe "#enable_network_manager!" do
    before do
      subject
    end

    it "adds the NetworkManager package to the list of resolvables " do
      expect(Yast::PackagesProposal).to receive(:AddResolvables)
        .with("network", :package, ["NetworkManager"])
      subject.enable_network_manager!
    end

    it "removes the wicked package from the list of resolvables " do
      expect(Yast::PackagesProposal).to receive(:RemoveResolvables)
        .with("network", :package, ["wicked"])
      subject.enable_network_manager!
    end

    it "sets :network_manager as the backend" do
      expect(subject.backend).to eql(:network_manager)
    end
  end

  describe "#network_manager_available?" do
    let(:package) { instance_double(Y2Packager::Package, status: :available) }
    let(:packages) { [package] }
    let(:settings) { described_class.instance }

    before do
      allow(settings).to receive(:network_manager_available?).and_call_original
      allow(Y2Packager::Package).to receive(:find).with("NetworkManager")
        .and_return(packages)
    end

    context "when there is no NetworkManager package available" do
      let(:packages) { [] }

      it "returns false" do
        expect(settings.network_manager_available?).to eql(false)
      end

      it "logs that the package is no available" do
        expect(settings.log).to receive(:info).with(/is not available/)
        settings.network_manager_available?
      end
    end

    context "when there are some NetworkManager packages available" do
      it "returns true" do
        expect(settings.network_manager_available?).to eql(true)
      end

      it "logs the status of the NetworkManager package" do
        expect(settings.log).to receive(:info).with(/status: available/)
        settings.network_manager_available?
      end
    end
  end
end
