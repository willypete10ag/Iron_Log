// lib/data/canonical_lifts.dart
class CanonicalLift {
  final String id;
  final String displayName;
  final List<String> aliases;
  final String group; // e.g., "Chest", "Triceps", ...

  const CanonicalLift({
    required this.id,
    required this.displayName,
    required this.aliases,
    required this.group,
  });
}

/// Display order for tabs/filters.
const List<String> kCanonicalGroups = <String>[
  'Chest',
  'Triceps',
  'Shoulders',
  'Rear Delt',
  'Back/Lats',
  'Legs – Quads',
  'Legs – Ham/Glutes',
  'Core/Abs',
];

const List<CanonicalLift> canonicalLifts = [
  // ===== Chest =====
  CanonicalLift(
    id: 'bench_flat_barbell',
    displayName: 'Flat Barbell Bench Press',
    aliases: [
      'flat barbell bench', 'flat bb bench', 'barbell bench', 'bench press', 'flat bench (bb)',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'bench_flat_dumbbell',
    displayName: 'Flat Dumbbell Bench Press',
    aliases: [
      'flat db bench', 'dumbbell bench', 'flat dumbbell press',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'bench_incline_barbell',
    displayName: 'Incline Barbell Bench Press',
    aliases: [
      'incline bb bench', 'incline barbell bench', 'incline barbell press',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'bench_incline_dumbbell',
    displayName: 'Incline Dumbbell Bench Press',
    aliases: [
      'incline db bench', 'incline dumbbell bench', 'incline dumbbell press',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'bench_flat_smith',
    displayName: 'Smith Machine Flat Bench',
    aliases: [
      'smith flat bench', 'smith flat press', 'smith bench flat',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'bench_incline_smith',
    displayName: 'Smith Machine Incline Bench',
    aliases: [
      'smith incline bench', 'smith incline press', 'smith incline bench press',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'cable_fly_bilateral_low_to_high',
    displayName: 'Cable Fly (Low → High, Both Arms)',
    aliases: [
      'bilateral cable fly low to high', 'cable flys down to up',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'cable_fly_bilateral_high_to_low',
    displayName: 'Cable Fly (High → Low, Both Arms)',
    aliases: [
      'bilateral cable fly high to low', 'cable flys up to down',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'cable_fly_bilateral_mid',
    displayName: 'Cable Fly (Straight Across, Both Arms)',
    aliases: [
      'cable fly straight ahead', 'flat cable fly standing',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'cable_fly_unilateral_low_to_high',
    displayName: 'Cable Fly (Low → High, Single Arm)',
    aliases: [
      'uni cable fly down to up', 'single arm cable fly low to high',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'db_fly_flat',
    displayName: 'Flat Dumbbell Fly',
    aliases: [
      'db fly flat', 'flat db fly', 'dumbbell fly flat bench',
    ],
    group: 'Chest',
  ),
  CanonicalLift(
    id: 'db_fly_incline',
    displayName: 'Incline Dumbbell Fly',
    aliases: [
      'incline db fly', 'incline dumbbell fly', 'incline chest fly db',
    ],
    group: 'Chest',
  ),

  // ===== Triceps =====
  CanonicalLift(
    id: 'skullcrusher_forehead_ezbar',
    displayName: 'Skull Crusher (Forehead, EZ Bar)',
    aliases: [
      'skull crusher to face', 'lying curl bar skull crusher face', 'ez bar skull crusher forehead',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'skullcrusher_behindhead_ezbar',
    displayName: 'Skull Crusher (Behind Head, EZ Bar)',
    aliases: [
      'skull crusher behind head', 'lying curl bar skull crusher behind head', 'ez bar skull crusher behind head',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'tricep_pushdown_bilateral',
    displayName: 'Tricep Pushdown (Cable, Both Arms)',
    aliases: [
      'bilateral tricep pushdown', 'rope pushdown both hands', 'cable pushdown both arms',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'tricep_pushdown_unilateral',
    displayName: 'Tricep Pushdown (Cable, Single Arm)',
    aliases: [
      'uni tricep pushdown', 'single arm tricep pushdown', 'one arm rope pushdown',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'overhead_tricep_ext_bilateral',
    displayName: 'Overhead Tricep Extension (Both Arms)',
    aliases: [
      'bilateral overhead tricep extension', 'two hand tricep extension',
      'overhead tricep cable both arms', 'db overhead tricep both arms',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'overhead_tricep_ext_unilateral',
    displayName: 'Overhead Tricep Extension (Single Arm)',
    aliases: [
      'uni overhead tricep extension', 'single arm overhead tricep',
      'one arm overhead tricep extension cable', 'single arm overhead db tricep',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'tricep_kickback',
    displayName: 'Tricep Kickback',
    aliases: [
      'tricep kickback', 'db tricep kickback', 'cable tricep kickback', 'single arm kickback',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'dips_unassisted',
    displayName: 'Dips (Bodyweight / Weighted)',
    aliases: [
      'dips', 'weighted dips', 'bodyweight dips', 'bar dips', 'parallel bar dips',
    ],
    group: 'Triceps',
  ),
  CanonicalLift(
    id: 'dips_assisted',
    displayName: 'Dips (Assisted)',
    aliases: [
      'assisted dips', 'dip assist machine', 'assisted dip machine',
    ],
    group: 'Triceps',
  ),

  // ===== Shoulders =====
  CanonicalLift(
    id: 'lateral_raise_db_standing_bilateral',
    displayName: 'DB Lateral Raise (Standing, Both Arms)',
    aliases: [
      'standing bilateral db lateral raises', 'standing lateral raise both', 'standing db lateral raise',
    ],
    group: 'Shoulders',
  ),
  CanonicalLift(
    id: 'lateral_raise_db_seated_unilateral',
    displayName: 'DB Lateral Raise (Seated, Single Arm)',
    aliases: [
      'uni seated db lateral raises', 'one arm seated lateral raise', 'seated single arm lateral raise',
    ],
    group: 'Shoulders',
  ),
  CanonicalLift(
    id: 'ohp_barbell_standing',
    displayName: 'Overhead Press (Barbell Standing)',
    aliases: [
      'ohp', 'standing barbell shoulder press', 'military press', 'standing ohp',
    ],
    group: 'Shoulders',
  ),
  CanonicalLift(
    id: 'shoulder_press_db_seated',
    displayName: 'Shoulder Press (Seated DB)',
    aliases: [
      'seated db shoulder press', 'seated dumbbell shoulder press', 'db shoulder press seated', 'db shoulder press',
    ],
    group: 'Shoulders',
  ),
  CanonicalLift(
    id: 'shoulder_press_smith',
    displayName: 'Shoulder Press (Smith Machine)',
    aliases: [
      'smith shoulder press', 'smith machine shoulder press', 'smith ohp', 'smith seated shoulder press',
    ],
    group: 'Shoulders',
  ),
  CanonicalLift(
    id: 'upright_row_barbell',
    displayName: 'Upright Row (Barbell/EZ)',
    aliases: [
      'upright row', 'barbell upright row', 'ez bar upright row', 'elbows high row', 'bar close elbows out high',
    ],
    group: 'Shoulders',
  ),

  // ===== Rear Delt =====
  CanonicalLift(
    id: 'rear_delt_fly_machine_or_cable',
    displayName: 'Rear Delt Fly (Machine/Cable)',
    aliases: [
      'reverse pec deck', 'reverse fly machine', 'rear delt fly', 'rear delt cable fly', 'reverse flies',
    ],
    group: 'Rear Delt',
  ),
  CanonicalLift(
    id: 'rear_delt_bar_sweep',
    displayName: 'Rear Delt Bar Sweep',
    aliases: [
      'rear delt bar sweep', 'rear delt bar pullback', 'bar behind you rear delt',
      'bend over 90 and thrust behind you and up',
    ],
    group: 'Rear Delt',
  ),

  // ===== Back / Lats =====
  CanonicalLift(
    id: 'lat_pulldown_machine',
    displayName: 'Lat Pulldown (Cable Machine)',
    aliases: [
      'lat pulldown machine', 'lat pulldown', 'wide grip pulldown', 'close grip pulldown',
    ],
    group: 'Back/Lats',
  ),
  CanonicalLift(
    id: 'pullup_unassisted',
    displayName: 'Pull-Up / Weighted Pull-Up',
    aliases: [
      'pull ups', 'pullups', 'weighted pull up', 'weighted pull-up', 'unassisted pull up',
    ],
    group: 'Back/Lats',
  ),
  CanonicalLift(
    id: 'pullup_assisted',
    displayName: 'Assisted Pull-Up',
    aliases: [
      'assisted pull up', 'assisted pullup machine', 'assisted pull-ups',
    ],
    group: 'Back/Lats',
  ),
  CanonicalLift(
    id: 'cable_pullover_straightarm',
    displayName: 'Cable Pullover (Straight Arm)',
    aliases: [
      'cable pullover', 'straight arm pulldown', 'straight arm cable pulldown', 'lat straight arm pulldown',
    ],
    group: 'Back/Lats',
  ),
  CanonicalLift(
    id: 'row_cable_seated_unilateral',
    displayName: 'Seated Cable Row (Single Arm)',
    aliases: [
      'uni seated cable row', 'single arm seated cable row', 'one arm cable row seated',
    ],
    group: 'Back/Lats',
  ),
  CanonicalLift(
    id: 'row_cable_seated_bilateral',
    displayName: 'Seated Cable Row (Both Arms)',
    aliases: [
      'bilateral cable row', 'cable row both arms', 'seated cable row', 'low row cable',
    ],
    group: 'Back/Lats',
  ),
  CanonicalLift(
    id: 'high_row_machine_or_cable',
    displayName: 'High Row (Machine/Cable)',
    aliases: [
      'high row', 'machine high row', 'cable high row', 'hammer strength high row',
    ],
    group: 'Back/Lats',
  ),
  CanonicalLift(
    id: 'shrug_bb_db_smith',
    displayName: 'Shrugs (BB/DB/Smith)',
    aliases: [
      'shrugs', 'bb shrugs', 'barbell shrugs', 'db shrugs', 'smith shrugs', 'trap shrugs',
    ],
    group: 'Back/Lats',
  ),

  // ===== Legs — Quads / General =====
  CanonicalLift(
    id: 'squat_back_barbell',
    displayName: 'Back Squat (Barbell)',
    aliases: [
      'bb back squat', 'barbell back squat', 'back squat', 'barbell squat', 'squat bb',
    ],
    group: 'Legs – Quads',
  ),
  CanonicalLift(
    id: 'squat_back_smith',
    displayName: 'Back Squat (Smith Machine)',
    aliases: [
      'smith back squat', 'smith squat', 'smith machine squat', 'smith machine back squat',
    ],
    group: 'Legs – Quads',
  ),
  CanonicalLift(
    id: 'leg_extension_machine',
    displayName: 'Leg Extension Machine',
    aliases: [
      'leg extension', 'leg ext machine', 'quad extension',
    ],
    group: 'Legs – Quads',
  ),
  CanonicalLift(
    id: 'hack_squat_machine',
    displayName: 'Hack Squat (Machine)',
    aliases: [
      'hack squat', 'machine hack squat', 'plate loaded hack squat', 'hack squat sled',
    ],
    group: 'Legs – Quads',
  ),
  CanonicalLift(
    id: 'leg_press_machine',
    displayName: 'Leg Press (Machine)',
    aliases: [
      'leg press', 'sled leg press', '45 degree leg press', 'plate loaded leg press',
    ],
    group: 'Legs – Quads',
  ),
  CanonicalLift(
    id: 'bulgarian_split_squat_db',
    displayName: 'Bulgarian Split Squat (DB)',
    aliases: [
      'bulgarian split squat', 'db bulgarian split squat', 'rear foot elevated split squat',
      'split squat dumbbell', 'bulgarian lunge db',
    ],
    group: 'Legs – Quads',
  ),
  CanonicalLift(
    id: 'lunge_bb_or_db',
    displayName: 'Lunge (BB or DB)',
    aliases: [
      'lunges', 'walking lunges', 'db lunges', 'bb lunges', 'dumbbell lunge', 'barbell lunge',
      'forward lunge', 'reverse lunge',
    ],
    group: 'Legs – Quads',
  ),
  CanonicalLift(
    id: 'goblet_squat',
    displayName: 'Goblet Squat',
    aliases: [
      'goblet squat', 'db goblet squat', 'kettlebell goblet squat', 'goblet squat dumbbell',
    ],
    group: 'Legs – Quads',
  ),

  // ===== Legs — Hamstrings / Glutes =====
  CanonicalLift(
    id: 'leg_curl_lying_machine',
    displayName: 'Leg Curl (Lying Machine)',
    aliases: [
      'lying leg curl', 'hamstring curl lying', 'prone leg curl',
    ],
    group: 'Legs – Ham/Glutes',
  ),
  CanonicalLift(
    id: 'leg_curl_seated_machine',
    displayName: 'Leg Curl (Seated Machine)',
    aliases: [
      'seated leg curl', 'leg curl seated', 'hamstring curl seated',
    ],
    group: 'Legs – Ham/Glutes',
  ),
  CanonicalLift(
    id: 'leg_curl_seated_single_leg',
    displayName: 'Leg Curl (Single-Leg Seated)',
    aliases: [
      'seated leg curl single leg', 'independent leg curl seated', 'one leg leg curl machine',
      'single leg ham curl',
    ],
    group: 'Legs – Ham/Glutes',
  ),
  CanonicalLift(
    id: 'hip_thrust_machine',
    displayName: 'Hip Thrust (Machine)',
    aliases: [
      'hip thrust machine', 'machine hip thrust', 'glute bridge machine', 'machine glute bridge', 'booty machine',
    ],
    group: 'Legs – Ham/Glutes',
  ),
  CanonicalLift(
    id: 'hammy_stretch_plate_hinge',
    displayName: 'Hammy Stretch',
    aliases: [
      'hammy stretch', 'hamstring stretch plate good morning', 'good morning on bench',
      'back extension with plate', 'hinge over bench with plate',
    ],
    group: 'Legs – Ham/Glutes',
  ),

  // ===== Core / Abs =====
  CanonicalLift(
    id: 'weighted_ab_crunch',
    displayName: 'Weighted Ab Crunch',
    aliases: [
      'weighted crunch', 'cable crunch', 'rope crunch', 'ab crunch weighted',
    ],
    group: 'Core/Abs',
  ),
  CanonicalLift(
    id: 'decline_situp',
    displayName: 'Decline Sit-Up',
    aliases: [
      'decline sit ups', 'decline situps', 'sit ups decline',
    ],
    group: 'Core/Abs',
  ),
  CanonicalLift(
    id: 'over_the_moons',
    displayName: 'Over the Moons',
    aliases: [
      'over the moons (abs)', 'sitting legs out straight hover feet over ball', 'over the moons abs',
    ],
    group: 'Core/Abs',
  ),
  CanonicalLift(
    id: 'captains_chair_leg_raises',
    displayName: "Captain's Chair Leg Raises",
    aliases: [
      'captains chair leg raises', 'captain chair leg raise', 'leg raises captains chair',
    ],
    group: 'Core/Abs',
  ),
];

/// Convenience lookups (evaluated at runtime).
final Map<String, CanonicalLift> canonicalById = {
  for (final l in canonicalLifts) l.id: l,
};

final Map<String, String> canonicalIdToGroup = {
  for (final l in canonicalLifts) l.id: l.group,
};
