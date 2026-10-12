package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
})

var _ = Describe("Scheduler Kit", func() {

	Describe("noble", func() {
		Test(Environment{
			Name:        "base",
			Exodus:      "base",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "base-route-registrar",
			Exodus:      "base-route-registrar",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})

	Describe("service-broker", func() {
		Test(Environment{
			Name:        "service-broker",
			Exodus:      "service-broker",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "service-broker-no-route",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("feature requires the"),
				GenesisCheck:      ContainSubstring("feature requires the"),
				GenesisManifest:   ContainSubstring("feature requires the"),
			},
		})
	})

	Describe("resolute", func() {
		Test(Environment{
			Name:        "resolute",
			Exodus:      "resolute",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-route-registrar",
			Exodus:      "resolute-route-registrar",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-ocf",
			CloudConfig: "aws-resolute-ocf",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-wrong-stemcell-os",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("stemcell os to"),
				GenesisCheck:      ContainSubstring("stemcell os to"),
				GenesisManifest:   ContainSubstring("stemcell os to"),
			},
		})
		Test(Environment{
			Name:        "resolute-stemcell-without-feature",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("Enable the feature and remove that parameter"),
				GenesisCheck:      ContainSubstring("Enable the feature and remove that parameter"),
				GenesisManifest:   ContainSubstring("Enable the feature and remove that parameter"),
			},
		})
	})
})
