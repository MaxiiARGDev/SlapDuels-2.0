--!strict
-- Global settings. Only active map clones are affected; V1 never resets during a match.
return table.freeze({
 Enabled = true,
 TargetPartName = "White_Part",
 GeometryFolderName = "Geometry",
 FadeDelay = 0,
 FadeDuration = 2,
 DetectionInterval = 0.1,
 DisableCollisionOnFadeComplete = true,
 ResetDuringMatch = false,
 SupportTolerance = 0.25,
 SurfaceTolerance = 0.05,
 TopNormalDot = 0.98,
 MaxSupportNormalSpeed = 4,
})
