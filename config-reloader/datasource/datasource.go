// Copyright © 2018 VMware, Inc. All Rights Reserved.
// SPDX-License-Identifier: BSD-2-Clause

package datasource

type Mount struct {
	Path       string
	VolumeName string
}

// MiniContainer container subset with the parent pod's metadata
type MiniContainer struct {
	// the pod id
	PodID   string
	PodName string

	// pod labels
	Labels map[string]string

	// container name
	Name string
	// only the emptyDir mounts, never empty, sorted by len(Path), descending
	HostMounts []*Mount

	NodeName string
}

// NamespaceConfig holds all relevant data for a namespace
type NamespaceConfig struct {
	Name               string
	FluentdConfig      string
	PreviousConfigHash string
	IsKnownFromBefore  bool
	MiniContainers     []*MiniContainer
	Labels             map[string]string
}

// StatusUpdater sets an error description on the namespace
// in case configuration cannot be applied or an empty string otherwise
type StatusUpdater interface {
	UpdateStatus(namespace string, status string)
}

// Datasource reads data from k8s
type Datasource interface {
	StatusUpdater
	GetNamespaces() ([]*NamespaceConfig, error)
	WriteCurrentConfigHash(namespace string, hash string)
}
