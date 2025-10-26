/// Virtio common device feature flags
pub const DeviceFeatures = struct {
    /// Negotiating this feature indicates that the driver can use descriptors with the VIRTQ_DESC_F_INDIRECT flag set, as described in 2.7.5.3 Indirect Descriptors and 2.8.7 Indirect Flag: Scatter-Gather Support.
    pub const VIRTIO_F_INDIRECT_DESC: u64 = 1 << 28;
    /// This feature enables the used_event and the avail_event fields as described in 2.7.7, 2.7.8 and 2.8.10.
    pub const VIRTIO_F_EVENT_IDX: u64 = 1 << 29;
    /// This indicates compliance with this specification, giving a simple way to detect legacy devices or drivers.
    pub const VIRTIO_F_VERSION_1: u64 = 1 << 32;
    /// This feature indicates that the driver passes extra data (besides identifying the virtqueue) in its device notifications. See 2.9 Driver Notifications.
    pub const VIRTIO_F_NOTIFICATION_DATA: u64 = 1 << 38;
};
