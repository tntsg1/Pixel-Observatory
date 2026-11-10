const bilingual = (en, zh) => ({ en, zh });

const question = (id, promptEn, promptZh, correctOptionId, options) => ({
  id,
  prompt: bilingual(promptEn, promptZh),
  options: options.map(([optionId, en, zh]) => ({ id: optionId, en, zh })),
  correctOptionId,
});

const form = (id, ...questions) => ({ id, questions });

// Browser and Worker consumers share this source, so its published data stays immutable.
const freezeDeep = value => {
  if (!value || typeof value !== "object" || Object.isFrozen(value)) return value;
  for (const nestedValue of Object.values(value)) freezeDeep(nestedValue);
  return Object.freeze(value);
};

export const RESEARCH_VERSION = "po_l1_24_matched_v1";

export const RESEARCH_NODES = freezeDeep([
  { id: "baseline", afterLevel: 1, nextLevel: 2, title: { en: "First Light", zh: "初见星光" } },
  { id: "A", afterLevel: 6, nextLevel: 7, title: { en: "Finding and Focusing", zh: "寻星与调焦" } },
  { id: "B", afterLevel: 11, nextLevel: 12, title: { en: "Magnification and Atmosphere", zh: "倍率与大气" } },
  { id: "C", afterLevel: 16, nextLevel: 17, title: { en: "Reflection and Collimation", zh: "反射与准直" } },
  { id: "D", afterLevel: 21, nextLevel: 22, title: { en: "Tracking and Evidence", zh: "追踪与证据" } },
  { id: "E", afterLevel: 24, nextLevel: null, title: { en: "Instrument Reasoning", zh: "仪器推理" } },
]);

export const QUESTION_FORMS = freezeDeep({
  baseline: [
    form(
      "baseline-form-1",
      question(
        "baseline-finder-before-main",
        "After locating a bright target in the sky, which tool should you use before looking through the main telescope?",
        "在天空中找到一个明亮目标后，使用主望远镜之前应先使用哪种工具？",
        "finder",
        [
          ["main", "Look immediately through the main telescope.", "立刻通过主望远镜观察。"],
          ["finder", "Use the finder scope to narrow and centre the target.", "使用寻星镜缩小范围并将目标居中。"],
          ["focus", "Turn the main focuser before aiming.", "在瞄准前转动主调焦器。"],
          ["not-sure", "I am not sure.", "我不确定。"],
        ],
      ),
      question(
        "baseline-focus-sharpness",
        "A centred star looks like a soft blob. Which adjustment most directly makes its image sharp?",
        "已经居中的恒星看起来像一团模糊光斑。哪项调整最直接地使图像清晰？",
        "focuser",
        [
          ["aperture", "Make the aperture smaller.", "把口径调小。"],
          ["finder", "Move the finder scope.", "移动寻星镜。"],
          ["focuser", "Adjust the focuser.", "调整调焦器。"],
          ["not-sure", "I am not sure.", "我不确定。"],
        ],
      ),
      question(
        "baseline-aperture-light",
        "Two telescopes use similar eyepieces. Why can the telescope with the larger aperture show a faint object more easily?",
        "两台望远镜使用相似的目镜。为什么口径更大的望远镜更容易看见暗弱目标？",
        "light",
        [
          ["magnification", "It automatically gives the highest magnification.", "它会自动提供最高倍率。"],
          ["tracking", "It stops Earth from rotating.", "它会让地球停止自转。"],
          ["not-sure", "I am not sure.", "我不确定。"],
          ["light", "It gathers more light from the object.", "它能从目标收集更多光线。"],
        ],
      ),
    ),
    form(
      "baseline-form-2",
      question(
        "baseline-finder-before-main",
        "Which order is normally most efficient when moving from a visible target to a telescope view?",
        "从肉眼可见的目标转入望远镜视野时，通常哪种顺序最高效？",
        "sequence",
        [
          ["reverse", "Main telescope, then finder scope, then naked eye.", "主望远镜、寻星镜、肉眼。"],
          ["focus", "Focuser, then main telescope, then finder scope.", "调焦器、主望远镜、寻星镜。"],
          ["sequence", "Naked eye, finder scope, then main telescope.", "肉眼、寻星镜、主望远镜。"],
          ["not-sure", "I am not sure.", "我不确定。"],
        ],
      ),
      question(
        "baseline-focus-sharpness",
        "Changing focus on a centred target normally does what?",
        "对已经居中的目标进行调焦通常会带来什么变化？",
        "sharpness",
        [
          ["brightness", "It makes every target brighter.", "它让所有目标变得更亮。"],
          ["direction", "It points the telescope to a different part of the sky.", "它让望远镜指向天空的另一个区域。"],
          ["not-sure", "I am not sure.", "我不确定。"],
          ["sharpness", "It changes image sharpness without directly increasing magnification.", "它改变图像清晰度，而不会直接提高倍率。"],
        ],
      ),
      question(
        "baseline-aperture-light",
        "If aperture increases while other observing conditions remain alike, what changes first?",
        "如果口径增大而其他观测条件保持相同，首先会发生什么变化？",
        "collect",
        [
          ["collect", "More of the object's light enters the telescope.", "更多来自目标的光线进入望远镜。"],
          ["colour", "The telescope removes every colour from the object.", "望远镜会去除目标的所有颜色。"],
          ["focus", "The focuser no longer matters.", "调焦器不再重要。"],
          ["not-sure", "I am not sure.", "我不确定。"],
        ],
      ),
    ),
    form(
      "baseline-form-3",
      question(
        "baseline-finder-before-main",
        "You can see a target with your eyes, but it is missing from the small main-telescope view. What is the best next tool?",
        "你能用肉眼看见目标，但它不在狭小的主望远镜视野中。下一步最适合使用什么工具？",
        "finder",
        [
          ["focuser", "The focuser, to make the empty view sharp.", "调焦器，让空白视野变清晰。"],
          ["aperture", "An aperture cover, to darken the view.", "口径盖，用来使视野变暗。"],
          ["not-sure", "I am not sure.", "我不确定。"],
          ["finder", "The finder scope, to aim the telescope at the target.", "寻星镜，用来将望远镜对准目标。"],
        ],
      ),
      question(
        "baseline-focus-sharpness",
        "Which control changes whether a star point looks crisp rather than fuzzy?",
        "哪种控制会改变恒星点看起来是清晰还是模糊？",
        "focus",
        [
          ["focus", "The focuser.", "调焦器。"],
          ["finder", "The finder-scope bracket.", "寻星镜支架。"],
          ["tripod", "The tripod height.", "三脚架高度。"],
          ["not-sure", "I am not sure.", "我不确定。"],
        ],
      ),
      question(
        "baseline-aperture-light",
        "What is the basic purpose of using a larger objective lens or mirror?",
        "使用更大口径物镜或主镜的基本目的是什么？",
        "gather",
        [
          ["rotate", "To rotate the sky more slowly.", "让天空转动得更慢。"],
          ["gather", "To gather a greater amount of light.", "收集更多光线。"],
          ["focus", "To replace the need for focusing.", "取代调焦的需要。"],
          ["not-sure", "I am not sure.", "我不确定。"],
        ],
      ),
    ),
  ],
  A: [
    form(
      "A-form-1",
      question(
        "a-field-of-view-sequence",
        "At the start of a difficult search, which approach moves from the widest view to the narrowest useful view?",
        "开始寻找较难的目标时，哪种方法是从最宽视野逐步转到最有用的窄视野？",
        "wide-to-narrow",
        [
          ["wide-to-narrow", "Use a finder or low-power view first, centre the target, then use a narrower view if needed.", "先使用寻星镜或低倍率视野，将目标居中后，再按需要转入更窄的视野。"],
          ["high-first", "Begin at the highest power, then try the finder scope.", "先用最高倍率，再尝试寻星镜。"],
          ["focus-first", "Keep changing focus before choosing a direction.", "在选择方向前不断改变焦点。"],
          ["aperture-first", "Change aperture before locating the target.", "在找到目标前先改变口径。"],
        ],
      ),
      question(
        "a-focus-not-magnification",
        "After a target is centred, why is careful focusing useful?",
        "目标居中后，为什么要认真调焦？",
        "sharpness",
        [
          ["sharpness", "It improves sharpness at the current magnification.", "它能在当前倍率下改善清晰度。"],
          ["size", "It increases the target's magnification by itself.", "它会自行提高目标的倍率。"],
          ["direction", "It makes the telescope point somewhere else.", "它让望远镜转向别处。"],
          ["light", "It makes the aperture collect more light.", "它使口径收集更多光线。"],
        ],
      ),
      question(
        "a-finder-alignment",
        "Why should a finder scope be aligned with the main telescope?",
        "为什么应该让寻星镜与主望远镜对准一致？",
        "same-target",
        [
          ["brightness", "It makes faint objects intrinsically brighter.", "它让暗弱目标本身变得更亮。"],
          ["same-target", "A target centred in the finder should also be in the main telescope's view.", "在寻星镜中居中的目标也应进入主望远镜视野。"],
          ["weather", "It clears clouds above the observatory.", "它能清除天文台上空的云。"],
          ["colour", "It removes colour from bright stars.", "它能去除亮星的颜色。"],
        ],
      ),
    ),
    form(
      "A-form-2",
      question(
        "a-field-of-view-sequence",
        "A galaxy is not visible through a high-power eyepiece. What is the most sensible first adjustment for finding it?",
        "在高倍率目镜中看不到一个星系。为了找到它，最合理的第一步调整是什么？",
        "wider",
        [
          ["higher", "Use an even higher-power eyepiece.", "使用倍率更高的目镜。"],
          ["wider", "Switch to a wider, lower-power view or use the finder scope.", "切换到更宽的低倍率视野，或使用寻星镜。"],
          ["focus", "Defocus until the galaxy fills the field.", "故意失焦，直到星系填满视野。"],
          ["cover", "Cover part of the aperture.", "遮住部分口径。"],
        ],
      ),
      question(
        "a-focus-not-magnification",
        "Which statement correctly separates focus from magnification?",
        "哪句话正确地区分了调焦和倍率？",
        "separate",
        [
          ["same", "Focus and magnification are the same control.", "调焦和倍率是同一种控制。"],
          ["separate", "Focus sharpens the image; magnification is changed by the optical setup, such as an eyepiece.", "调焦使图像清晰；倍率由目镜等光学配置改变。"],
          ["reverse", "Focus makes the field wider, while magnification sharpens the image.", "调焦使视野变宽，而倍率使图像清晰。"],
          ["weather", "Both controls only change the weather.", "两种控制都只改变天气。"],
        ],
      ),
      question(
        "a-finder-alignment",
        "A star is centred in a finder but missing from the main eyepiece. What does this most strongly suggest?",
        "一颗恒星在寻星镜中已经居中，却没有出现在主目镜中。这最可能说明什么？",
        "misaligned",
        [
          ["large-aperture", "The aperture is too large.", "口径太大。"],
          ["overfocused", "The telescope has too much focus.", "望远镜调焦过多。"],
          ["misaligned", "The finder and main telescope are not aligned on the same direction.", "寻星镜与主望远镜没有对准同一个方向。"],
          ["colour", "The star has changed colour.", "恒星改变了颜色。"],
        ],
      ),
    ),
    form(
      "A-form-3",
      question(
        "a-field-of-view-sequence",
        "Why is a low-power eyepiece often chosen before a high-power eyepiece when acquiring a target?",
        "为什么在寻找目标时，通常先选低倍率目镜，再选高倍率目镜？",
        "wide-field",
        [
          ["more-colour", "It adds more colour to every object.", "它会给每个目标增加更多颜色。"],
          ["no-focus", "It never needs focusing.", "它永远不需要调焦。"],
          ["wide-field", "Its wider field makes it easier to place the target before narrowing the view.", "它的视野更宽，便于在缩小视野前先把目标放进去。"],
          ["more-light", "It makes the aperture physically larger.", "它会让口径在物理上变大。"],
        ],
      ),
      question(
        "a-focus-not-magnification",
        "A planet is the desired size in the eyepiece but its edge is soft. What should you change first?",
        "行星在目镜中的大小已经合适，但边缘发虚。首先应改变什么？",
        "focus",
        [
          ["eyepiece", "Use a higher-power eyepiece immediately.", "立刻换成倍率更高的目镜。"],
          ["finder", "Aim only with the finder scope.", "只用寻星镜重新瞄准。"],
          ["focus", "Adjust focus for a sharper image.", "调整焦点，让图像更清晰。"],
          ["aperture", "Reduce the aperture to make the planet smaller.", "减小口径，让行星变小。"],
        ],
      ),
      question(
        "a-finder-alignment",
        "What practical result shows that finder alignment is working?",
        "什么实际结果表明寻星镜校准有效？",
        "agreement",
        [
          ["brightness", "Every object becomes brighter in both views.", "每个目标在两个视野中都会变亮。"],
          ["magnification", "Both views have exactly the same magnification.", "两个视野具有完全相同的倍率。"],
          ["weather", "The sky becomes free of turbulence.", "天空不再有大气扰动。"],
          ["agreement", "The same centred object appears where expected in both views.", "同一个居中目标会按预期出现在两个视野中。"],
        ],
      ),
    ),
  ],
  B: [
    form(
      "B-form-1",
      question(
        "b-useful-magnification-ceiling",
        "A planet looks larger at a very high setting but reveals less detail and looks unsteady. What is the best conclusion?",
        "行星在极高倍率下看起来更大，却显示更少细节且不稳定。最合理的结论是什么？",
        "useful-limit",
        [
          ["always-more", "More magnification always creates more detail.", "更高倍率总会产生更多细节。"],
          ["focus-only", "The problem can only be fixed by focusing.", "这个问题只能靠调焦解决。"],
          ["useful-limit", "The observation has passed a useful magnification limit set by the telescope and atmosphere.", "观测已超过由望远镜和大气共同限制的有效倍率。"],
          ["aperture-cover", "Covering the aperture will add detail.", "遮住口径会增加细节。"],
        ],
      ),
      question(
        "b-poor-seeing",
        "On a night of poor atmospheric seeing, which observing choice is usually wiser?",
        "在大气视宁度较差的夜晚，通常哪种观测选择更明智？",
        "lower-power",
        [
          ["maximum", "Use the highest available magnification at once.", "立刻使用可用的最高倍率。"],
          ["ignore", "Ignore the moving and boiling image.", "忽略不断晃动和翻滚的图像。"],
          ["finder", "Use the finder scope as the final observing view.", "把寻星镜作为最终观测视野。"],
          ["lower-power", "Use a lower, more useful magnification or wait for steadier air.", "使用较低但更有效的倍率，或等待空气更稳定。"],
        ],
      ),
      question(
        "b-earth-rotation-drift",
        "Why does a centred star slowly leave an untracked telescope view?",
        "为什么居中的恒星会慢慢离开没有追踪的望远镜视野？",
        "earth-rotation",
        [
          ["earth-rotation", "Earth's rotation makes the sky appear to drift across the field.", "地球自转让天空看起来穿过视野漂移。"],
          ["battery", "The eyepiece battery is draining.", "目镜电池正在耗尽。"],
          ["aperture", "The aperture has become smaller.", "口径变小了。"],
          ["focus", "The focuser slowly moves the sky.", "调焦器慢慢移动了天空。"],
        ],
      ),
    ),
    form(
      "B-form-2",
      question(
        "b-useful-magnification-ceiling",
        "What best describes a useful magnification ceiling?",
        "哪项最准确地描述了有效倍率上限？",
        "limit",
        [
          ["brightness", "It is the point where every target becomes brighter.", "它是每个目标都会变亮的临界点。"],
          ["finder", "It is the widest field of the finder scope.", "它是寻星镜最宽的视野。"],
          ["colour", "It is the colour of the main mirror.", "它是主镜的颜色。"],
          ["limit", "Beyond it, enlarging the image no longer reveals reliable new detail.", "超过它后，继续放大图像不再显示可靠的新细节。"],
        ],
      ),
      question(
        "b-poor-seeing",
        "Which observation is a common sign of poor seeing rather than a focusing mistake?",
        "哪种现象通常说明视宁度差，而不是调焦失误？",
        "dancing",
        [
          ["dancing", "A well-focused star or planet edge keeps dancing and changing rapidly.", "已经调好焦的恒星或行星边缘仍不断跳动、快速变化。"],
          ["fixed-blur", "The image is equally soft and stays still at every moment.", "图像始终同样模糊，而且每一刻都静止不动。"],
          ["finder-mark", "The finder crosshair is visible.", "寻星镜十字线可见。"],
          ["larger-lens", "The objective lens is larger.", "物镜更大。"],
        ],
      ),
      question(
        "b-earth-rotation-drift",
        "What does telescope tracking do during a long observation?",
        "长时间观测时，望远镜追踪的作用是什么？",
        "counter-drift",
        [
          ["increase-light", "It increases the aperture's light gathering.", "它提高口径的集光能力。"],
          ["counter-drift", "It moves the telescope to counter the sky's apparent drift.", "它移动望远镜，以抵消天空的视运动漂移。"],
          ["change-colour", "It changes the target's colour.", "它改变目标的颜色。"],
          ["replace-focus", "It replaces the need to focus.", "它取代调焦的需要。"],
        ],
      ),
    ),
    form(
      "B-form-3",
      question(
        "b-useful-magnification-ceiling",
        "Why is choosing the maximum printed magnification not always a good observing strategy?",
        "为什么选择标注的最大倍率并不总是一个好的观测策略？",
        "detail-limit",
        [
          ["detail-limit", "Atmospheric and optical limits can make the larger image dimmer or less detailed.", "大气和光学限制会让更大的图像变暗或细节更少。"],
          ["automatic-focus", "Maximum magnification automatically focuses the telescope.", "最大倍率会自动给望远镜调焦。"],
          ["tracking", "Maximum magnification stops all drift.", "最大倍率会停止所有漂移。"],
          ["finder", "Maximum magnification widens the finder scope.", "最大倍率会扩大寻星镜视野。"],
        ],
      ),
      question(
        "b-poor-seeing",
        "A high-power view of Jupiter ripples from moment to moment even after careful focus. What should you try?",
        "经过认真调焦后，木星的高倍率视野仍每时每刻都在波动。你应该尝试什么？",
        "reduce",
        [
          ["increase", "Increase magnification until the ripples disappear.", "不断提高倍率，直到波动消失。"],
          ["reduce", "Reduce magnification and see whether the image becomes more usable.", "降低倍率，看看图像是否更易使用。"],
          ["ignore", "Treat the ripples as extra planetary detail.", "把这些波动当作额外的行星细节。"],
          ["aperture", "Close the finder scope cap.", "盖上寻星镜镜盖。"],
        ],
      ),
      question(
        "b-earth-rotation-drift",
        "An observer keeps nudging a telescope westward to keep a star centred. Which system would reduce this repeated correction?",
        "观测者不断向西微调望远镜，才能让恒星保持居中。哪种系统能减少这种重复修正？",
        "tracking",
        [
          ["focus", "A finer focuser.", "更精细的调焦器。"],
          ["aperture", "A smaller objective lens.", "更小的物镜。"],
          ["tracking", "A tracking mount that follows the sky's apparent motion.", "能够跟随天空视运动的追踪支架。"],
          ["finder", "A wider finder reticle.", "更宽的寻星镜十字线。"],
        ],
      ),
    ),
  ],
  C: [
    form(
      "C-form-1",
      question(
        "c-newtonian-reflection-path",
        "Which path describes light in a Newtonian reflecting telescope?",
        "哪条路径正确描述了牛顿式反射望远镜中的光路？",
        "primary-secondary-eyepiece",
        [
          ["lens-only", "It passes through one large lens directly to the eyepiece.", "它穿过一块大透镜后直接到达目镜。"],
          ["primary-secondary-eyepiece", "It reflects from the primary mirror to a small secondary mirror, then into the side eyepiece.", "它从主镜反射到小型副镜，再进入侧面的目镜。"],
          ["eyepiece-first", "It reaches the eyepiece before touching a mirror.", "它先到达目镜，再接触镜面。"],
          ["secondary-sky", "It reflects from the secondary mirror back into the sky.", "它从副镜反射回天空。"],
        ],
      ),
      question(
        "c-collimation",
        "What is the purpose of collimating a reflector?",
        "给反射望远镜准直的目的是什么？",
        "mirror-axis",
        [
          ["colour", "To add a blue fringe around every star.", "给每颗星增加蓝色边缘。"],
          ["tracking", "To make Earth rotate more slowly.", "让地球自转更慢。"],
          ["mirror-axis", "To align the mirrors so their optical axes send light to the intended focus.", "让镜面光轴对齐，使光线汇聚到预期焦点。"],
          ["aperture", "To change the mirror's diameter.", "改变主镜直径。"],
        ],
      ),
      question(
        "c-chromatic-aberration-comparison",
        "Why is a simple reflector less prone to chromatic aberration than a simple refractor?",
        "为什么简单反射望远镜通常比简单折射望远镜更不易产生色差？",
        "mirrors",
        [
          ["focuser", "Reflectors have no need for focusing.", "反射望远镜不需要调焦。"],
          ["tracking", "Reflectors automatically track the sky.", "反射望远镜会自动追踪天空。"],
          ["finder", "Reflectors use no finder scope.", "反射望远镜不用寻星镜。"],
          ["mirrors", "Mirrors reflect different visible colours without separating them by lens refraction in the same way.", "镜面反射不同可见光颜色时，不会像透镜折射那样把它们分开。"],
        ],
      ),
    ),
    form(
      "C-form-2",
      question(
        "c-newtonian-reflection-path",
        "In a Newtonian telescope, what redirects the converging beam toward the eyepiece on the side of the tube?",
        "在牛顿式望远镜中，什么部件把会聚光束转向镜筒侧面的目镜？",
        "secondary",
        [
          ["primary", "The large primary mirror, directly through the tube wall.", "大主镜，直接穿过镜筒壁。"],
          ["finder", "The finder-scope lens.", "寻星镜透镜。"],
          ["secondary", "The small flat secondary mirror near the front of the tube.", "靠近镜筒前端的小型平面副镜。"],
          ["tripod", "The tripod head.", "三脚架云台。"],
        ],
      ),
      question(
        "c-collimation",
        "A reflector gives asymmetrical, misshapen star images even at careful focus. Which maintenance check is most relevant?",
        "反射望远镜即使认真调焦后，恒星图像仍不对称、形状异常。哪项维护检查最相关？",
        "collimation",
        [
          ["colour", "Change the star's colour setting.", "改变恒星的颜色设置。"],
          ["tracking", "Turn off all tracking.", "关闭所有追踪。"],
          ["aperture", "Make the aperture smaller than the finder scope.", "把口径缩小到比寻星镜还小。"],
          ["collimation", "Check collimation of the primary and secondary mirrors.", "检查主镜与副镜的准直。"],
        ],
      ),
      question(
        "c-chromatic-aberration-comparison",
        "A bright star has red and blue fringes in a simple lens telescope. What optical effect is being observed?",
        "明亮恒星在简单透镜望远镜中出现红蓝边缘。观察到的是什么光学效应？",
        "dispersion",
        [
          ["dispersion", "Different colours are refracted by different amounts in the lens.", "不同颜色的光在透镜中折射程度不同。"],
          ["tracking", "The mount is tracking too accurately.", "支架追踪得过于准确。"],
          ["collimation", "The mirror is perfectly collimated.", "镜面准直得非常完美。"],
          ["aperture", "The lens is collecting too much light.", "透镜收集了过多光线。"],
        ],
      ),
    ),
    form(
      "C-form-3",
      question(
        "c-newtonian-reflection-path",
        "What is the large concave mirror at the bottom of a Newtonian tube used for?",
        "牛顿式镜筒底部的大型凹面镜有什么作用？",
        "primary",
        [
          ["focus", "It is only used to turn the focuser knob.", "它只用来转动调焦旋钮。"],
          ["finder", "It shows a wider finder view.", "它显示更宽的寻星镜视野。"],
          ["tracking", "It moves the mount with Earth's rotation.", "它随着地球自转移动支架。"],
          ["primary", "It gathers incoming light and reflects it toward the secondary mirror.", "它收集入射光，并把光反射向副镜。"],
        ],
      ),
      question(
        "c-collimation",
        "Which statement about collimation is correct?",
        "关于准直，哪句话是正确的？",
        "alignment",
        [
          ["alignment", "It is mirror alignment, not a way to increase magnification.", "它是镜面校准，而不是提高倍率的方法。"],
          ["brightness", "It guarantees brighter clouds.", "它保证云层更亮。"],
          ["weather", "It removes atmospheric turbulence.", "它能消除大气扰动。"],
          ["colour", "It intentionally creates coloured fringes.", "它会故意制造彩色边缘。"],
        ],
      ),
      question(
        "c-chromatic-aberration-comparison",
        "Which design is most directly affected by colour-dependent bending of light?",
        "哪种设计最直接受到不同颜色光弯折程度不同的影响？",
        "refractor",
        [
          ["reflector", "A mirror-based reflector.", "基于镜面的反射望远镜。"],
          ["refractor", "A simple lens-based refractor.", "简单的透镜式折射望远镜。"],
          ["mount", "A tracking mount.", "追踪支架。"],
          ["finder", "A finder bracket.", "寻星镜支架。"],
        ],
      ),
    ),
  ],
  D: [
    form(
      "D-form-1",
      question(
        "d-condition-distinction",
        "Which matching of observing condition to image effect is most accurate?",
        "哪组观测条件与图像效果的对应最准确？",
        "conditions",
        [
          ["reverse", "Cloud improves contrast, light pollution sharpens stars, and poor seeing gathers more light.", "云层提高对比度，光污染使恒星变清晰，视宁度差收集更多光。"],
          ["focus", "All three conditions are solved by the focuser alone.", "这三种情况都能仅靠调焦器解决。"],
          ["tracking", "All three conditions are caused by tracking.", "这三种情况都由追踪引起。"],
          ["conditions", "Cloud reduces incoming light, light pollution brightens the background, and poor seeing makes fine detail dance.", "云层减少入射光，光污染使背景变亮，视宁度差让细节跳动。"],
        ],
      ),
      question(
        "d-evidence-quality",
        "Which observation record provides the strongest evidence for later comparison?",
        "哪种观测记录能为后续比较提供最有力的证据？",
        "complete-record",
        [
          ["complete-record", "The target, time, instrument settings, exposure, observing conditions, and original image or note.", "目标、时间、仪器设置、曝光、观测条件以及原始图像或记录。"],
          ["memory", "A memory that the image looked better tonight.", "记得今晚图像看起来更好。"],
          ["title", "Only a decorative title for the image.", "只给图像取一个装饰性标题。"],
          ["guess", "A guess about what caused the change.", "猜测变化的原因。"],
        ],
      ),
      question(
        "d-configuration-causality",
        "How can an observer best test whether a focus setting caused a change in image sharpness?",
        "观测者如何最好地检验某个焦点设置是否导致图像清晰度变化？",
        "controlled-change",
        [
          ["controlled-change", "Change focus deliberately, keep relevant conditions as steady as possible, and record the before-and-after result.", "有意改变焦点，尽量保持相关条件稳定，并记录前后结果。"],
          ["all-change", "Change focus, eyepiece, target, and weather at the same time.", "同时改变焦点、目镜、目标和天气。"],
          ["memory", "Rely only on how the image felt several nights later.", "只依靠几晚后对图像的感觉。"],
          ["ignore", "Ignore the configuration and compare only colours.", "忽略配置，只比较颜色。"],
        ],
      ),
    ),
    form(
      "D-form-2",
      question(
        "d-condition-distinction",
        "Stars are still visible, but their edges jitter rapidly while the sky background is not uniformly brighter. Which condition is most likely?",
        "恒星仍可见，但边缘快速抖动，而天空背景并没有整体变亮。最可能是什么情况？",
        "seeing",
        [
          ["seeing", "Poor atmospheric seeing.", "大气视宁度差。"],
          ["cloud", "Thick cloud cover.", "浓厚云层。"],
          ["light-pollution", "Light pollution alone.", "仅仅是光污染。"],
          ["aperture", "A larger aperture.", "更大的口径。"],
        ],
      ),
      question(
        "d-evidence-quality",
        "You want to compare two eyepieces fairly. Which method improves the quality of the evidence?",
        "你想公平比较两个目镜。哪种方法能提高证据质量？",
        "repeat",
        [
          ["switch", "Switch every setting at once and keep no notes.", "一次切换所有设置，不做任何记录。"],
          ["repeat", "Use the same target under noted conditions, record each configuration, and repeat the comparison.", "在记录好的条件下观察同一目标，记录每种配置，并重复比较。"],
          ["claim", "Choose the eyepiece with the more confident claim.", "选择说法更自信的目镜。"],
          ["social", "Ask which eyepiece has the prettier name.", "询问哪个目镜名字更好看。"],
        ],
      ),
      question(
        "d-configuration-causality",
        "A screenshot becomes sharper after one recorded adjustment. What makes a configuration-to-image conclusion more credible?",
        "一次有记录的调整后，截图变清晰了。什么能使“配置导致图像变化”的结论更可信？",
        "repeatable",
        [
          ["unrelated", "A different target looked impressive at another time.", "另一个目标在别的时间看起来很壮观。"],
          ["repeatable", "The same adjustment produces a similar effect in repeat observations with the configuration recorded.", "在记录配置的重复观测中，同样的调整产生相似效果。"],
          ["colour", "The interface colour changed after the screenshot.", "截图后界面颜色改变了。"],
          ["guess", "The observer likes the new setting more.", "观测者更喜欢新设置。"],
        ],
      ),
    ),
    form(
      "D-form-3",
      question(
        "d-condition-distinction",
        "A faint nebula is hard to distinguish against a bright grey sky, with no cloud crossing the field. What is the most direct explanation?",
        "一团暗弱星云很难从明亮灰色的天空背景中分辨出来，视野中没有云经过。最直接的解释是什么？",
        "light-pollution",
        [
          ["tracking", "Tracking has made the nebula too bright.", "追踪让星云变得太亮。"],
          ["light-pollution", "Sky glow from light pollution has reduced contrast.", "光污染造成的天空背景光降低了对比度。"],
          ["collimation", "Perfect collimation has hidden the nebula.", "完美准直把星云藏起来了。"],
          ["focus", "The focuser has changed the time of night.", "调焦器改变了夜晚的时间。"],
        ],
      ),
      question(
        "d-evidence-quality",
        "Which item is least useful as evidence that a configuration caused an image change?",
        "哪一项最不适合作为配置导致图像变化的证据？",
        "memory-only",
        [
          ["settings", "A saved list of settings used for the image.", "保存的图像设置列表。"],
          ["conditions", "Notes about target and observing conditions.", "关于目标和观测条件的记录。"],
          ["memory-only", "An unrecorded memory that it seemed sharper.", "没有记录的记忆，觉得它似乎更清晰。"],
          ["comparison", "A repeatable before-and-after comparison.", "可重复的前后对比。"],
        ],
      ),
      question(
        "d-configuration-causality",
        "Why should an observer avoid changing many settings at once when investigating an image change?",
        "为什么观测者在研究图像变化时应避免一次改变许多设置？",
        "confounded",
        [
          ["brightness", "It makes every target intrinsically brighter.", "它会让每个目标本身更亮。"],
          ["tracking", "It permanently stops Earth rotation.", "它会永久停止地球自转。"],
          ["confounded", "It becomes hard to tell which configuration change produced the effect.", "这样会很难判断究竟是哪项配置变化产生了效果。"],
          ["colour", "It turns radio data into visible light.", "它会把无线电数据变成可见光。"],
        ],
      ),
    ),
  ],
  E: [
    form(
      "E-form-1",
      question(
        "e-target-instrument-choice",
        "Which setup is most suitable for observing a faint, wide nebula?",
        "哪种配置最适合观测一团暗弱而宽广的星云？",
        "wide-faint",
        [
          ["tiny-high", "The narrowest possible field at the highest available magnification.", "在最高可用倍率下使用最窄的视野。"],
          ["wide-faint", "A light-gathering telescope with a wide, low-power field that can contain the nebula.", "具有较强集光能力、并能容纳整团星云的宽广低倍率视野望远镜。"],
          ["finder-only", "Only a finder scope, with no main telescope.", "只使用寻星镜，不使用主望远镜。"],
          ["indoor", "Any telescope pointed at an indoor wall.", "把任意望远镜对准室内墙壁。"],
        ],
      ),
      question(
        "e-infrared-false-colour",
        "What do colours in an infrared false-colour image usually represent?",
        "红外假彩色图像中的颜色通常代表什么？",
        "mapped-data",
        [
          ["visible-colour", "Exactly the colours a human eye would see at the target.", "人眼在目标处会看到的完全相同的颜色。"],
          ["temperature-only", "Only the target's surface temperature, with no other data choices.", "只代表目标表面温度，不包含其他数据选择。"],
          ["mapped-data", "A chosen mapping from infrared filters or intensities into visible display colours.", "把红外滤镜或强度按照选定规则映射为屏幕可见颜色。"],
          ["radio", "A record of audio sound from the target.", "目标发出的音频声音记录。"],
        ],
      ),
      question(
        "e-radio-versus-optical",
        "What is the key difference between a radio map and an optical image?",
        "无线电图与光学图像之间的关键区别是什么？",
        "wavelength",
        [
          ["shape", "Radio data can never be shown as an image.", "无线电数据永远不能显示为图像。"],
          ["colour", "Optical images have colour, but radio data have no values to display.", "光学图像有颜色，而无线电数据没有可显示的数值。"],
          ["focus", "Radio observations are only different because they have no focus.", "无线电观测的区别只是没有焦点。"],
          ["wavelength", "The radio map measures radio-wavelength emission, while an optical image measures visible light.", "无线电图测量无线电波段辐射，而光学图像测量可见光。"],
        ],
      ),
    ),
    form(
      "E-form-2",
      question(
        "e-target-instrument-choice",
        "For small planetary detail on a steady night, which choice is most reasoned?",
        "在大气稳定的夜晚，为观察细小的行星细节，哪种选择最合理？",
        "appropriate-power",
        [
          ["maximum-only", "Use the maximum magnification printed on any eyepiece regardless of the image.", "不看图像情况，使用任意目镜标注的最大倍率。"],
          ["wide-only", "Use the widest finder view because all planets are wide objects.", "因为所有行星都是宽广目标，所以只用最宽的寻星镜视野。"],
          ["appropriate-power", "Use an instrument with enough resolving power and an appropriate useful magnification for the conditions.", "选择分辨能力足够的仪器，并在当前条件下使用合适的有效倍率。"],
          ["random", "Choose a telescope by the colour of its tube.", "按镜筒颜色选择望远镜。"],
        ],
      ),
      question(
        "e-infrared-false-colour",
        "An infrared image displays a dusty region in orange. What should an observer check before claiming the dust is visibly orange?",
        "一幅红外图把尘埃区域显示为橙色。观测者在断言尘埃肉眼可见为橙色之前，应先检查什么？",
        "legend",
        [
          ["focuser", "Whether the optical focuser is locked.", "光学调焦器是否锁定。"],
          ["tracking", "Whether Earth stopped rotating.", "地球是否停止自转。"],
          ["aperture", "Whether the aperture is completely covered.", "口径是否被完全遮住。"],
          ["legend", "The image legend and which infrared filters or values were assigned to orange.", "图例，以及哪些红外滤镜或数值被分配为橙色。"],
        ],
      ),
      question(
        "e-radio-versus-optical",
        "A colourful radio-data visualization resembles a photograph. What is the careful interpretation?",
        "一幅色彩丰富的无线电数据可视化看起来像照片。谨慎的解释是什么？",
        "visualization",
        [
          ["visualization", "The colours can visualize measured radio intensity; they do not make it an optical photograph.", "这些颜色可以把测得的无线电强度可视化，但这并不使它成为光学照片。"],
          ["photo", "It must show the same visible colours an astronaut would see.", "它一定显示宇航员会看到的相同可见颜色。"],
          ["audio", "It contains no measurements because radio waves are sound only.", "它不包含测量数据，因为无线电波只是声音。"],
          ["focus", "It is an optical image whenever it is in focus.", "只要清晰，它就是一幅光学图像。"],
        ],
      ),
    ),
    form(
      "E-form-3",
      question(
        "e-target-instrument-choice",
        "Which observing plan best matches a compact bright planet rather than a faint extended nebula?",
        "哪种观测方案更适合紧凑明亮的行星，而不是暗弱扩展的星云？",
        "planet-plan",
        [
          ["nebula-plan", "Always use the widest possible field with no concern for detail.", "始终使用最宽视野，完全不关注细节。"],
          ["finder-plan", "Use only the finder scope because it has a crosshair.", "只使用带十字线的寻星镜。"],
          ["random-plan", "Choose the setup at random after the image appears.", "图像出现后随机选择配置。"],
          ["planet-plan", "Use useful moderate or higher magnification when the atmosphere is steady enough to support detail.", "在大气足够稳定、能支持细节时，使用有效的中高倍率。"],
        ],
      ),
      question(
        "e-infrared-false-colour",
        "Why do scientists use false colour for infrared data?",
        "科学家为什么为红外数据使用假彩色？",
        "translate",
        [
          ["translate", "It translates differences in non-visible infrared measurements into visible differences that people can inspect.", "它把不可见红外测量中的差异转换为人们可以检查的可见差异。"],
          ["decorate", "It decorates the data without representing measurements.", "它只是装饰数据，并不代表测量。"],
          ["remove", "It removes all information about wavelength.", "它去除了所有与波长有关的信息。"],
          ["optical", "It changes infrared photons into ordinary camera light at the target.", "它在目标处把红外光子变成普通相机光。"],
        ],
      ),
      question(
        "e-radio-versus-optical",
        "Which statement about radio and optical astronomy is correct?",
        "关于无线电天文学和光学天文学，哪句话是正确的？",
        "different-data",
        [
          ["same-data", "Both instruments always measure the same visible photons.", "两种仪器总是测量相同的可见光子。"],
          ["different-data", "They can observe the same target but measure different wavelength ranges and physical signals.", "它们可以观测同一目标，但测量不同的波长范围和物理信号。"],
          ["no-image", "Radio measurements cannot be mapped into an image.", "无线电测量不能映射为图像。"],
          ["colour-only", "Their only difference is the colour used in a display.", "它们唯一的区别是显示所用的颜色。"],
        ],
      ),
    ),
  ],
});

export const TEXT_ARCHIVE_MODULES = freezeDeep({
  baseline: {
    id: "baseline",
    title: bilingual("First Light", "初见星光"),
    body: bilingual(
      "A telescope shows only a small part of the sky, so target finding works best as a sequence. First locate the bright target with your eyes, then centre it in the finder scope, and only then move to the main telescope. Each step narrows the field of view. Skipping the finder can leave the target outside the main telescope's much smaller view even when the telescope is pointing close to the correct place.\n\nA soft, round star is usually a focus problem. The focuser changes where the converging light reaches a sharp point; it does not change the telescope's aperture or the target's true position. Adjust it in small steps and compare the star before and after each movement. The sharpest setting is the one that produces the smallest, cleanest star image.\n\nAperture is the diameter of the main light-collecting lens or mirror. A larger aperture gathers more light, so faint objects can be easier to detect and more detail may become available under suitable conditions. Aperture is different from magnification: an eyepiece can enlarge an image, but it cannot replace light that the telescope never collected.",
      "望远镜一次只能显示天空中的一小部分，因此寻找目标最好按顺序进行。先用肉眼找到明亮目标，再把它放到寻星镜中央，最后才切换到主望远镜。每一步都会缩小视野。如果跳过寻星镜，即使望远镜已经大致指向正确方向，目标也可能仍在主望远镜狭窄视野之外。\n\n柔软、圆钝的星点通常说明调焦有问题。调焦器改变会聚光线形成清晰焦点的位置，不会改变望远镜口径，也不会改变目标的真实位置。应当小幅调整，并比较每次移动前后的星点。能形成最小、最干净星像的位置就是最清晰的焦点。\n\n口径是主要集光透镜或镜面的直径。更大的口径能够收集更多光线，因此在条件合适时，暗弱天体更容易被发现，也可能呈现更多细节。口径不同于倍率：目镜可以放大图像，却不能补回望远镜从未收集到的光。"
    ),
    diagrams: [],
    conceptIds: ["baseline-finder-sequence", "baseline-focus", "baseline-aperture"],
  },
  A: {
    id: "A",
    title: bilingual("Finding and Focusing", "寻星与调焦"),
    body: bilingual(
      "Finding a target is easier when you deliberately move from a wide view to a narrow one. Start with the naked-eye sky or a finder scope, where a large patch of sky is visible. Place the target near the finder crosshair, then look through a low-power eyepiece in the main telescope. A low-power eyepiece shows a wider field than a high-power eyepiece, so it gives you room to correct your aim. Once the target is centred, you can switch to a narrower view only when it helps the observation. Starting at high power often makes a familiar object feel lost because the field is so small.\n\nFocus answers a different question from magnification. Focus changes whether the light from the target forms a crisp image at the eyepiece. It does not make the target physically larger. Magnification is set by the telescope and the eyepiece combination. If a planet is the size you want but its edge looks soft, adjust focus first. If the image is sharp but the target is too small or too large for the task, choose a different eyepiece later. Keeping those controls separate helps you diagnose what to change.\n\nThe finder scope must also agree with the main telescope. Alignment means that an object centred in the finder appears in the expected place when you look through the main eyepiece. Check this on a distant, safe target or a bright celestial target, then make small alignment adjustments. A well-aligned finder does not add magnification or brightness. Its job is to connect the wide search view to the narrow observing view, so your careful aiming is not lost at the handoff.",
      "寻找目标时，最好有意识地从宽视野逐步转到窄视野。先用肉眼观察天空，或使用能看到较大天空范围的寻星镜。把目标放到寻星镜十字线附近，再通过主望远镜中的低倍率目镜观察。低倍率目镜比高倍率目镜的视野更宽，因此你有余地修正指向。目标居中后，只有在有助于观察时才转入更窄的视野。若一开始就用高倍率，熟悉的目标也常会因为视野太小而像是丢失了。\n\n调焦回答的问题与倍率不同。调焦改变目标的光线是否在目镜处形成清晰图像，它不会让目标本身变大。倍率由望远镜和目镜的组合决定。如果行星大小已经合适但边缘发虚，应先调焦；如果图像已经清晰，而目标对当前任务来说过大或过小，之后再更换目镜。把两种控制分开理解，才能判断该调整什么。\n\n寻星镜也必须与主望远镜指向一致。校准的意思是：在寻星镜中居中的物体，应该出现在主目镜的预期位置。可选择远处且安全的目标，或明亮天体进行检查，再做小幅校准。校准良好的寻星镜不会增加倍率或亮度，它的作用是把宽广的寻找视野与狭窄的观测视野连接起来，避免仔细瞄准后在切换时丢失目标。"
    ),
    diagrams: [
      {
        id: "a-wide-to-narrow",
        label: bilingual("Diagram 1: Wide-to-narrow target acquisition", "图示 1：从宽到窄寻找目标"),
        description: bilingual("A left-to-right sequence shows the same target first in the naked-eye sky, then inside a finder crosshair, then centred in a low-power eyepiece, and finally in a narrower observing view.", "从左到右的顺序展示同一目标：先在肉眼天空中，再在寻星镜十字线内，随后在低倍率目镜中居中，最后进入更窄的观测视野。"),
        labels: [
          bilingual("Wide sky: locate the target", "宽广天空：找到目标"),
          bilingual("Finder: centre the target", "寻星镜：让目标居中"),
          bilingual("Low power: confirm placement", "低倍率：确认位置"),
          bilingual("Narrow view: inspect detail", "窄视野：检查细节"),
        ],
      },
      {
        id: "a-focus-and-alignment",
        label: bilingual("Diagram 2: Separate controls, shared aim", "图示 2：控制不同，指向一致"),
        description: bilingual("One panel marks the focuser changing a soft star point into a crisp point. A second panel shows finder and main-telescope sight lines meeting at the same target.", "一个面板标示调焦器把模糊星点变为清晰星点；另一个面板展示寻星镜和主望远镜的视线都对准同一个目标。"),
        labels: [
          bilingual("Focuser: changes sharpness", "调焦器：改变清晰度"),
          bilingual("Eyepiece: sets the viewing scale", "目镜：设定观察尺度"),
          bilingual("Finder line of sight", "寻星镜视线"),
          bilingual("Main telescope line of sight", "主望远镜视线"),
        ],
      },
    ],
    conceptIds: ["a-field-of-view-sequence", "a-focus-not-magnification", "a-finder-alignment"],
  },
  B: {
    id: "B",
    title: bilingual("Magnification and Atmosphere", "倍率与大气"),
    body: bilingual(
      "Magnification can make an object look larger, but a larger image is not automatically a more informative one. Every observing system has a useful range. The telescope optics and aperture set how much fine detail the instrument can deliver, while the moving atmosphere can further blur that detail. When you push past the useful magnification ceiling, the target may occupy more of the eyepiece but look dimmer, softer, or less steady. The productive choice is the magnification that makes real detail easiest to see, not simply the largest number printed on an eyepiece.\n\nAtmospheric seeing describes how steadily the air lets light travel. On a poor-seeing night, a focused star can shimmer and a planetary edge can ripple from moment to moment. That motion is not proof that the focuser is wrong. First use careful focus, then lower the magnification if the view remains unstable. Lower power can make the available detail easier to interpret because it does not enlarge the atmosphere's changing distortions as strongly. Waiting for steadier air can help too.\n\nEven under clear, steady conditions, a target will drift across an untracked telescope field. The sky appears to move because Earth rotates. A tracking mount moves the telescope in the opposite apparent direction, keeping the target near the chosen position for longer. Tracking does not create extra resolution, brighten a faint object, or repair poor seeing. It simply prevents predictable drift, which gives the observer more time to focus, inspect, and record what the instrument is already capable of showing.",
      "倍率可以让目标看起来更大，但更大的图像并不一定包含更多信息。每个观测系统都有一个有效范围。望远镜的光学质量和口径决定仪器本身能提供多少细节，而不断运动的大气还会进一步模糊这些细节。超过有效倍率上限后，目标可能占据更多目镜视野，却显得更暗、更软或更不稳定。真正有用的选择是让真实细节最容易看清的倍率，而不只是目镜上标注最大的数字。\n\n大气视宁度描述空气让光线稳定通过的程度。在视宁度差的夜晚，即使已经调好焦，恒星也可能闪烁，行星边缘也会每时每刻起伏。这种运动并不能证明调焦器有问题。先仔细调焦，如果图像仍不稳定，就降低倍率。较低倍率不会那么强烈地放大大气不断变化的扭曲，因此可用细节会更容易辨认。等待空气更稳定也可能有帮助。\n\n即使天空晴朗而稳定，未追踪的望远镜中目标仍会漂过视野。天空看起来在移动，是因为地球自转。追踪支架会让望远镜朝相反的视运动方向移动，使目标能在选定位置停留更久。追踪不会制造额外分辨率、不会让暗弱目标变亮，也不能修复视宁度差；它只防止可预测的漂移，让观测者有更多时间调焦、检查并记录仪器原本能够呈现的内容。"
    ),
    diagrams: [
      {
        id: "b-useful-magnification",
        label: bilingual("Diagram 1: Useful magnification versus empty enlargement", "图示 1：有效倍率与空洞放大"),
        description: bilingual("Three views of one planet show a useful middle magnification with readable bands, then a larger but softer view after the useful limit is exceeded.", "同一颗行星的三个视图展示中间倍率下可辨认的条纹，以及超过有效上限后更大却更柔软的图像。"),
        labels: [
          bilingual("Too low: target is small", "过低：目标太小"),
          bilingual("Useful: real detail is readable", "有效：真实细节可辨认"),
          bilingual("Too high: larger, not clearer", "过高：更大，但不更清晰"),
          bilingual("Atmosphere and optics set the limit", "大气与光学共同设限"),
        ],
      },
      {
        id: "b-seeing-and-tracking",
        label: bilingual("Diagram 2: Air motion and sky drift", "图示 2：空气运动与天空漂移"),
        description: bilingual("The first panel compares a steady star edge with a rapidly wavering one. The second panel traces a star crossing an untracked field and remaining centred when a mount follows the apparent motion.", "第一个面板比较稳定的星点边缘与快速摇晃的边缘；第二个面板描绘恒星穿过未追踪视野，以及支架跟随视运动后保持居中的情况。"),
        labels: [
          bilingual("Steady air", "稳定空气"),
          bilingual("Poor seeing: detail wavers", "视宁度差：细节波动"),
          bilingual("Untracked: target drifts", "未追踪：目标漂移"),
          bilingual("Tracking: mount counters drift", "追踪：支架抵消漂移"),
        ],
      },
    ],
    conceptIds: ["b-useful-magnification-ceiling", "b-poor-seeing", "b-earth-rotation-drift"],
  },
  C: {
    id: "C",
    title: bilingual("Reflection and Collimation", "反射与准直"),
    body: bilingual(
      "A Newtonian telescope uses mirrors to bring light to the observer. Light enters the open front of the tube and travels to the large concave primary mirror at the bottom. The primary mirror gathers the light and sends the converging beam back toward the front. Before the beam leaves the tube, a small flat secondary mirror redirects it sideways into the focuser and eyepiece. This folded path lets a long optical path fit inside a practical tube while placing the observer at the side of the instrument.\n\nFor that path to work well, the mirrors must be collimated. Collimation is the alignment of the primary and secondary mirrors so their optical axes guide light to the intended focus. If the mirrors are tilted away from the expected geometry, a carefully focused star can still look uneven or distorted. Collimation is not another name for focus. Focus moves the eyepiece position to sharpen the image at a chosen optical alignment; collimation restores the optical alignment itself. Check collimation with an appropriate star test or alignment tool, and make measured adjustments rather than random ones.\n\nReflectors also illustrate why different telescope designs have different colour behaviour. A simple refracting telescope uses a lens, and a lens bends different visible colours by slightly different amounts. Bright objects can therefore show coloured fringes when those colours do not reach exactly the same focus. Mirrors reflect visible colours without splitting them by refraction in the same way, so a well-made reflector is much less prone to this particular chromatic aberration. That advantage does not remove the need for focus or collimation; it describes one specific difference between lenses and mirrors.",
      "牛顿式望远镜用镜面把光线带到观测者眼前。光线从镜筒前端的开口进入，来到筒底的大型凹面主镜。主镜收集光线，并把会聚光束反射回前方。光束离开镜筒前，会被一块小型平面副镜转向侧面，进入调焦器和目镜。这条折叠光路能让较长的光学路径装进实用的镜筒，同时把观测者放在仪器侧面。\n\n为了让这条光路良好工作，镜面必须准直。准直是对主镜和副镜的校准，使它们的光轴把光线导向预期焦点。如果镜面偏离应有的几何关系，即使认真调焦，恒星图像仍可能不均匀或变形。准直不是调焦的另一种说法。调焦是在既定光学对齐下移动目镜位置来使图像清晰；准直则是恢复光学对齐本身。可以使用合适的星点测试或校准工具检查准直，并进行有根据的小幅调整，而不是随意调节。\n\n反射望远镜也说明了不同设计为何有不同的颜色表现。简单折射望远镜使用透镜，而透镜会让不同可见光颜色产生略有不同的折射。明亮目标因此可能出现彩色边缘，因为这些颜色没有准确落在同一焦点上。镜面反射可见光时不会以同样方式通过折射把颜色分开，所以制作良好的反射望远镜较不易出现这种特定的色差。这个优势并不意味着不需要调焦或准直；它只描述了透镜和镜面之间的一项特定差异。"
    ),
    diagrams: [
      {
        id: "c-newtonian-path",
        label: bilingual("Diagram 1: Newtonian reflection path", "图示 1：牛顿式反射光路"),
        description: bilingual("A tube cross-section traces incoming light to the concave primary mirror, then to the small diagonal secondary mirror, and finally sideways through the focuser to the eyepiece.", "镜筒剖面追踪入射光到凹面主镜，再到小型斜置副镜，最后经调焦器横向进入目镜。"),
        labels: [
          bilingual("Incoming starlight", "入射星光"),
          bilingual("Primary mirror", "主镜"),
          bilingual("Secondary mirror", "副镜"),
          bilingual("Focuser and eyepiece", "调焦器与目镜"),
        ],
      },
      {
        id: "c-alignment-and-colour",
        label: bilingual("Diagram 2: Alignment and colour behaviour", "图示 2：校准与颜色表现"),
        description: bilingual("One panel contrasts aligned and misaligned mirror axes. A second panel contrasts a lens bringing blue and red light to slightly different foci with a mirror reflecting both colours along the same path.", "一个面板对比对齐与失准的镜面光轴；另一个面板对比透镜将蓝光和红光汇聚到略不同焦点，与镜面让两种颜色沿同一路径反射的情况。"),
        labels: [
          bilingual("Aligned optical axis", "对齐的光轴"),
          bilingual("Misaligned optical axis", "失准的光轴"),
          bilingual("Lens: colour-dependent refraction", "透镜：颜色相关的折射"),
          bilingual("Mirror: shared reflection path", "镜面：共享反射路径"),
        ],
      },
    ],
    conceptIds: ["c-newtonian-reflection-path", "c-collimation", "c-chromatic-aberration-comparison"],
  },
  D: {
    id: "D",
    title: bilingual("Tracking and Evidence", "追踪与证据"),
    body: bilingual(
      "An image can change for several reasons, and naming the reason correctly matters. Cloud blocks or dims incoming light, sometimes unevenly across the field. Light pollution adds sky glow, so faint objects lose contrast against a brighter background. Poor atmospheric seeing is different again: moving air bends light by changing amounts, making fine planetary detail or star edges wobble quickly. These effects can occur together, but they call for different interpretations. A dim image is not automatically a focus problem, and a shimmering edge is not automatically a cloud.\n\nGood observing evidence preserves the context needed to compare results. Record the target, date and time, telescope and eyepiece, focus or tracking settings when relevant, exposure or image settings, and the sky conditions. Keep the original image or a clear observation note. A remembered impression can start a question, but it is weak evidence by itself because memory changes and conditions may have changed too. A short, complete record allows another observer, or your future self, to see what was actually configured.\n\nTo reason from configuration to image, make a controlled comparison. Change one meaningful setting, keep the target and other relevant conditions as steady as practical, and record what changes. Repeat when possible. If focus is the variable, compare before and after focus under the same target and similar conditions. If an eyepiece is the variable, record both eyepieces and avoid changing the mount, target, and exposure at the same moment. This does not make every observation perfect, but it makes the causal claim more honest: the evidence supports a specific connection rather than a convenient guess.",
      "图像会因为多种原因而变化，正确说出原因很重要。云层会挡住或减弱入射光，有时还会让视野不同区域受影响不均。光污染会增加天空背景光，使暗弱目标在更明亮的背景前失去对比度。大气视宁度差又是另一回事：运动的空气以不断变化的程度弯折光线，让细小的行星细节或恒星边缘快速摇晃。这些影响可能同时出现，但需要不同的解释。图像变暗不一定是调焦问题，边缘闪动也不一定是云。\n\n良好的观测证据会保留比较结果所需的背景。记录目标、日期和时间、望远镜和目镜、相关的焦点或追踪设置、曝光或图像设置以及天空条件。保留原始图像或清楚的观测笔记。回忆中的印象可以成为问题的起点，但单独来看是很弱的证据，因为记忆会改变，条件也可能已经改变。简短而完整的记录能让另一位观测者，或未来的你，知道当时实际使用了什么配置。\n\n要从配置推理到图像，应做受控比较。改变一个有意义的设置，尽可能让目标和其他相关条件保持稳定，并记录发生的变化；可能时应重复。如果研究的是焦点，就在同一目标和相近条件下比较调焦前后。如果研究的是目镜，就记录两只目镜，不要在同一时刻又改变支架、目标和曝光。这样不能让每次观测都完美，却能让因果判断更诚实：证据支持的是一个明确联系，而不是一个方便的猜测。"
    ),
    diagrams: [
      {
        id: "d-condition-diagnosis",
        label: bilingual("Diagram 1: Diagnose the changing view", "图示 1：诊断变化中的视野"),
        description: bilingual("Three panels show a dimmed field behind cloud, a faint target against bright sky glow, and a sharp target edge that rapidly wavers in poor seeing.", "三个面板分别展示云后变暗的视野、明亮天空背景前的暗弱目标，以及视宁度差时快速摇晃的清晰目标边缘。"),
        labels: [
          bilingual("Cloud: less incoming light", "云层：入射光更少"),
          bilingual("Light pollution: brighter background", "光污染：背景更亮"),
          bilingual("Poor seeing: detail moves", "视宁度差：细节晃动"),
          bilingual("Do not diagnose by one symptom alone", "不要只凭一个症状判断"),
        ],
      },
      {
        id: "d-evidence-chain",
        label: bilingual("Diagram 2: From configuration to evidence", "图示 2：从配置到证据"),
        description: bilingual("A four-step record links a named configuration, noted conditions, a before-and-after image, and a repeat check before drawing a causal conclusion.", "一条四步记录把明确配置、已记录条件、前后图像和重复检查连接起来，然后才作出因果结论。"),
        labels: [
          bilingual("Configuration", "配置"),
          bilingual("Conditions", "条件"),
          bilingual("Recorded result", "记录的结果"),
          bilingual("Repeat before concluding", "结论前先重复"),
        ],
      },
    ],
    conceptIds: ["d-condition-distinction", "d-evidence-quality", "d-configuration-causality"],
  },
  E: {
    id: "E",
    title: bilingual("Instrument Reasoning", "仪器推理"),
    body: bilingual(
      "Instrument reasoning starts with the target, not with a favourite setting. A faint, extended nebula benefits from light gathering and a field wide enough to contain its structure. For a compact bright planet, the goal is different: use an instrument with enough resolving power and choose a useful magnification that the atmosphere can support. The largest number is not automatically best. A suitable setup matches the target's size, brightness, and the kind of detail you want to inspect. It also matches the observing conditions, because a turbulent night can limit a fine-detail plan.\n\nImages made from infrared observations require another kind of reasoning. Infrared wavelengths are outside ordinary human vision, so a displayed colour is often a deliberate mapping from a filter or measured intensity to a visible screen colour. An orange dust lane in a false-colour image does not by itself prove that your eyes would see orange dust there. The image legend explains what the colours represent. False colour is useful precisely because it makes differences in otherwise invisible measurements easier to compare, as long as the mapping is stated clearly.\n\nRadio data are different from optical images as well. A radio telescope measures emission at radio wavelengths, whereas an optical telescope records visible light. Both can observe the same galaxy, but they can reveal different physical processes. A radio map may be displayed with dramatic colours and a familiar image shape, yet those colours normally encode measured radio intensity or another chosen data value. Treat the result as a visualization of radio measurements, not as an ordinary visible-light photograph. Reading the target, the instrument, the wavelength, and the display key together produces a more reliable interpretation than trusting appearance alone.",
      "仪器推理应从目标出发，而不是从自己偏爱的设置出发。一团暗弱、扩展的星云需要较强的集光能力，以及足以容纳其结构的宽视野。紧凑而明亮的行星则不同：目标是使用分辨能力足够的仪器，并选择大气条件能够支持的有效倍率。最大的数字并不自动最好。合适的配置要匹配目标的大小、亮度和你想检查的细节类型，也要匹配观测条件，因为大气扰动会限制精细细节的方案。\n\n由红外观测制作的图像还需要另一种推理。红外波长超出普通人眼的视觉范围，因此屏幕上的颜色通常是把某个滤镜或测量强度有意映射为可见颜色的结果。假彩色图中的橙色尘埃带本身并不能证明你的眼睛会在那个地方看见橙色尘埃。图例会说明颜色代表什么。假彩色之所以有用，正是因为它让原本不可见测量中的差异更易比较，前提是映射规则被清楚说明。\n\n无线电数据也与光学图像不同。无线电望远镜测量无线电波段辐射，而光学望远镜记录可见光。两者可以观测同一个星系，却能揭示不同的物理过程。无线电图可能用醒目的颜色呈现熟悉的图像形状，但这些颜色通常编码的是测得的无线电强度，或另一种选定的数据数值。应把它理解为无线电测量的可视化，而不是普通的可见光照片。把目标、仪器、波长和显示图例结合起来阅读，比只相信外观更可靠。"
    ),
    diagrams: [
      {
        id: "e-target-to-instrument",
        label: bilingual("Diagram 1: Match the instrument to the target", "图示 1：让仪器匹配目标"),
        description: bilingual("A comparison pairs a faint wide nebula with light gathering and a wide field, then pairs a compact planet with useful detail-oriented magnification under steady air.", "一组对比把暗弱宽广的星云与集光能力和宽视野配对，再把紧凑行星与稳定空气下关注细节的有效倍率配对。"),
        labels: [
          bilingual("Faint extended nebula", "暗弱扩展星云"),
          bilingual("Light gathering and wide field", "集光能力与宽视野"),
          bilingual("Compact bright planet", "紧凑明亮行星"),
          bilingual("Useful detail-oriented magnification", "面向细节的有效倍率"),
        ],
      },
      {
        id: "e-data-to-display",
        label: bilingual("Diagram 2: From wavelength data to display colour", "图示 2：从波长数据到显示颜色"),
        description: bilingual("Two paths show infrared filters and radio intensity measurements being assigned display colours through a labelled legend; neither path claims to show ordinary eye colour by default.", "两条路径展示红外滤镜和无线电强度测量如何通过带标签的图例分配显示颜色；两条路径都不会默认声称展示人眼看到的普通颜色。"),
        labels: [
          bilingual("Infrared measurement", "红外测量"),
          bilingual("Radio measurement", "无线电测量"),
          bilingual("Legend maps data to colour", "图例将数据映射为颜色"),
          bilingual("Display is not automatically eye colour", "显示颜色不自动等于人眼颜色"),
        ],
      },
    ],
    conceptIds: ["e-target-instrument-choice", "e-infrared-false-colour", "e-radio-versus-optical"],
  },
});

export const COSMETIC_BUNDLES = freezeDeep([
  {
    id: "R01",
    name: bilingual("Solar Crown", "日冕王冠"),
    avatar: "R01-avatar",
    frame: "R01-frame",
    background: "R01-background",
    nameGlow: "R01-name-glow",
    chatBubble: "R01-chat-bubble",
    badge: "R01-badge",
    title: "R01-title",
  },
  {
    id: "R02",
    name: bilingual("Lunar Archive", "月面档案"),
    avatar: "R02-avatar",
    frame: "R02-frame",
    background: "R02-background",
    nameGlow: "R02-name-glow",
    chatBubble: "R02-chat-bubble",
    badge: "R02-badge",
    title: "R02-title",
  },
  {
    id: "R03",
    name: bilingual("Nebula Weaver", "星云织者"),
    avatar: "R03-avatar",
    frame: "R03-frame",
    background: "R03-background",
    nameGlow: "R03-name-glow",
    chatBubble: "R03-chat-bubble",
    badge: "R03-badge",
    title: "R03-title",
  },
  {
    id: "R04",
    name: bilingual("Aurora Navigator", "极光领航"),
    avatar: "R04-avatar",
    frame: "R04-frame",
    background: "R04-background",
    nameGlow: "R04-name-glow",
    chatBubble: "R04-chat-bubble",
    badge: "R04-badge",
    title: "R04-title",
  },
  {
    id: "R05",
    name: bilingual("Pulsar Herald", "脉冲使者"),
    avatar: "R05-avatar",
    frame: "R05-frame",
    background: "R05-background",
    nameGlow: "R05-name-glow",
    chatBubble: "R05-chat-bubble",
    badge: "R05-badge",
    title: "R05-title",
  },
  {
    id: "R06",
    name: bilingual("Event Horizon", "事件视界"),
    avatar: "R06-avatar",
    frame: "R06-frame",
    background: "R06-background",
    nameGlow: "R06-name-glow",
    chatBubble: "R06-chat-bubble",
    badge: "R06-badge",
    title: "R06-title",
  },
  {
    id: "R07",
    name: bilingual("Deep Sky Cartographer", "深空制图"),
    avatar: "R07-avatar",
    frame: "R07-frame",
    background: "R07-background",
    nameGlow: "R07-name-glow",
    chatBubble: "R07-chat-bubble",
    badge: "R07-badge",
    title: "R07-title",
  },
  {
    id: "R08",
    name: bilingual("Infrared Alchemist", "红外炼金"),
    avatar: "R08-avatar",
    frame: "R08-frame",
    background: "R08-background",
    nameGlow: "R08-name-glow",
    chatBubble: "R08-chat-bubble",
    badge: "R08-badge",
    title: "R08-title",
  },
  {
    id: "R09",
    name: bilingual("Radio Sentinel", "射电哨兵"),
    avatar: "R09-avatar",
    frame: "R09-frame",
    background: "R09-background",
    nameGlow: "R09-name-glow",
    chatBubble: "R09-chat-bubble",
    badge: "R09-badge",
    title: "R09-title",
  },
  {
    id: "R10",
    name: bilingual("Mirror Master", "镜面大师"),
    avatar: "R10-avatar",
    frame: "R10-frame",
    background: "R10-background",
    nameGlow: "R10-name-glow",
    chatBubble: "R10-chat-bubble",
    badge: "R10-badge",
    title: "R10-title",
  },
  {
    id: "R11",
    name: bilingual("Sidereal Voyager", "恒星时旅者"),
    avatar: "R11-avatar",
    frame: "R11-frame",
    background: "R11-background",
    nameGlow: "R11-name-glow",
    chatBubble: "R11-chat-bubble",
    badge: "R11-badge",
    title: "R11-title",
  },
  {
    id: "R12",
    name: bilingual("Observatory Laureate", "天文台桂冠"),
    avatar: "R12-avatar",
    frame: "R12-frame",
    background: "R12-background",
    nameGlow: "R12-name-glow",
    chatBubble: "R12-chat-bubble",
    badge: "R12-badge",
    title: "R12-title",
  },
]);
