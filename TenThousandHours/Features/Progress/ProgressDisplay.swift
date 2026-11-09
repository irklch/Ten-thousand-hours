struct ProgressDisplay {
    let progress: ProgressSnapshot

    var percentText: String { ProgressFormatter.percent(progress) }
    var hoursText: String { ProgressFormatter.hours(progress) }
    var filledDotCount: Int { progress.filledDotCount }
    var accessibilitySummary: String { ProgressFormatter.accessibilitySummary(progress) }
}
