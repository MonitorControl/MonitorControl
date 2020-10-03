import DDC

extension EDID {
    public func displayName() -> String? {
        let descriptors = [self.descriptors.0, self.descriptors.1, self.descriptors.2, self.descriptors.3]

        for descriptor in descriptors {
            switch descriptor {
            case let .displayName(name):
                return name
            default:
                continue
            }
        }

        return nil
    }
}
