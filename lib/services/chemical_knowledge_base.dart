/// 化学知识图谱数据 — 预置知识点与匹配工具
///
/// 用途:
/// - 化合物结构式识别后,将 SMILES / 化合物名 关联到教材知识点
/// - 学情诊断时统计各知识点的掌握度
/// - 个性化学习路径生成(基于知识点依赖关系)
///
/// 覆盖范围:
/// - 有机化学(organic): 烃及其衍生物、糖蛋白质高分子等(高中+大学)
/// - 无机化学(inorganic): 酸碱盐氧化物金属非金属配合物(初中+高中+大学)
/// - 物理化学(physical): 酸碱理论/氧化还原/化学平衡/电化学(高中+大学)
///
/// 数据规范:
/// - 知识点 ID: kp_<category>_<topic>
/// - 学段 stage: middle(初中) / highschool(高中) / college(大学),多学段用逗号分隔
/// - 章节参照人教版化学教材(必修一/二、选修5、九年级上下册、大学分科教材)
/// - functionalGroups 为简化 SMILES 片段,用于子串匹配(非严格 SMARTS)
/// - relatedPointIds 表示该知识点的后继(产物/衍生)节点,用于构建依赖图
import '../models/knowledge_point.dart';

class ChemicalKnowledgeBase {
  /// 所有预置知识点
  static const List<KnowledgePoint> allPoints = [
    // ==================== 有机化学 organic ====================

    // 1. 烷烃
    KnowledgePoint(
      id: 'kp_organic_alkane',
      name: '烷烃',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第一章 认识有机化合物',
      description: '饱和链烃,碳碳单键,通式 CnH2n+2,典型代表甲烷、乙烷、丙烷。'
          '可发生取代反应(卤代)、氧化(燃烧),化学性质较稳定。',
      keywords: [
        '烷烃', '甲烷', '乙烷', '丙烷', '丁烷', '戊烷', '己烷', '正己烷',
        '异戊烷', '新戊烷', '饱和烃', 'alkane', 'methane', 'ethane',
        'propane', 'butane', 'CH4', 'C2H6', '天然气',
      ],
      relatedPointIds: ['kp_organic_alkene', 'kp_organic_halide'],
      functionalGroups: ['CC'],
      difficulty: 2,
    ),

    // 2. 烯烃
    KnowledgePoint(
      id: 'kp_organic_alkene',
      name: '烯烃',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第二章 脂肪烃',
      description: '含碳碳双键 C=C 的不饱和链烃,通式 CnH2n(单烯烃)。'
          '可发生加成(加氢/加卤/加卤化氢)、加聚、氧化反应。',
      keywords: [
        '烯烃', '乙烯', '丙烯', '丁烯', '异丁烯', '不饱和烃',
        'alkene', 'ethylene', 'propylene', 'C2H4',
      ],
      relatedPointIds: [
        'kp_organic_alkane', 'kp_organic_halide',
        'kp_organic_polymer', 'kp_organic_alcohol',
      ],
      functionalGroups: ['C=C'],
      difficulty: 2,
    ),

    // 3. 炔烃
    KnowledgePoint(
      id: 'kp_organic_alkyne',
      name: '炔烃',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第二章 脂肪烃',
      description: '含碳碳三键 C≡C 的不饱和链烃,通式 CnH2n-2。'
          '代表物乙炔,可发生加成反应,端基炔氢有弱酸性。',
      keywords: [
        '炔烃', '乙炔', '丙炔', '电石气', 'alkyne', 'acetylene',
        'C2H2', '不饱和烃',
      ],
      relatedPointIds: ['kp_organic_alkene'],
      functionalGroups: ['C#C'],
      difficulty: 3,
    ),

    // 4. 芳香烃
    KnowledgePoint(
      id: 'kp_organic_aromatic',
      name: '芳香烃',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第二章 芳香烃',
      description: '含苯环的烃,苯环具有特殊稳定性(大π键)。代表物苯、甲苯、二甲苯。'
          '可发生取代(硝化/卤代/磺化)和加成反应。',
      keywords: [
        '芳香烃', '苯', '甲苯', '二甲苯', '苯环', '芳烃', 'aromatic',
        'benzene', 'toluene', 'xylene', 'C6H6', 'C7H8',
      ],
      relatedPointIds: ['kp_organic_phenol', 'kp_organic_nitro', 'kp_organic_halide'],
      functionalGroups: ['c1ccccc1', 'cccc'],
      difficulty: 3,
    ),

    // 5. 卤代烃
    KnowledgePoint(
      id: 'kp_organic_halide',
      name: '卤代烃',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第二章 卤代烃',
      description: '烃分子中氢原子被卤素原子取代的产物,含 C-X 键。'
          '可发生水解(取代)反应生成醇,消去反应生成烯烃。',
      keywords: [
        '卤代烃', '卤代烷', '氯甲烷', '溴乙烷', '氯乙烷', '氯乙烯',
        '四氯化碳', '氯仿', '三氯甲烷', 'halide', 'alkyl halide',
        'CH3Cl', 'C2H5Br',
      ],
      relatedPointIds: ['kp_organic_alcohol', 'kp_organic_alkene'],
      functionalGroups: ['CCl', 'CBr', 'CF', 'CI', 'C(Cl)', 'C(Br)', 'C(F)', 'C(I)'],
      difficulty: 3,
    ),

    // 6. 醇
    KnowledgePoint(
      id: 'kp_organic_alcohol',
      name: '醇',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第三章 烃的含氧衍生物',
      description: '羟基 -OH 与链烃基相连的化合物(R-OH)。代表物甲醇、乙醇。'
          '可发生取代(与钠)、消去(脱水成烯)、氧化(成醛/酮)、酯化反应。',
      keywords: [
        '醇', '醇类', '甲醇', '乙醇', '酒精', '丙醇', '异丙醇', '丁醇',
        '甘油', '丙三醇', 'alcohol', 'methanol', 'ethanol', 'CH3OH', 'C2H5OH',
      ],
      relatedPointIds: [
        'kp_organic_aldehyde', 'kp_organic_ether',
        'kp_organic_ester', 'kp_organic_alkene',
      ],
      functionalGroups: ['CO', 'C(O)'],
      difficulty: 3,
    ),

    // 7. 酚
    KnowledgePoint(
      id: 'kp_organic_phenol',
      name: '酚',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第三章 烃的含氧衍生物',
      description: '羟基直接连在苯环上的化合物(Ar-OH)。代表物苯酚。'
          '有弱酸性,可与溴水发生取代反应(生成三溴苯酚白色沉淀)。',
      keywords: [
        '酚', '苯酚', '石炭酸', '酚类', '甲酚', 'phenol', 'C6H5OH',
      ],
      relatedPointIds: ['kp_organic_aromatic'],
      functionalGroups: ['Oc1ccccc1', 'Oc1ccccc'],
      difficulty: 3,
    ),

    // 8. 醚
    KnowledgePoint(
      id: 'kp_organic_ether',
      name: '醚',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第三章 烃的含氧衍生物',
      description: '两个烃基通过氧原子连接的化合物(R-O-R\')。代表物乙醚。'
          '性质较稳定,常用作溶剂。',
      keywords: [
        '醚', '乙醚', '甲醚', '醚类', 'ether', 'diethyl ether', 'C2H5OC2H5',
      ],
      relatedPointIds: ['kp_organic_alcohol'],
      functionalGroups: ['COC', 'C(O)C'],
      difficulty: 3,
    ),

    // 9. 醛
    KnowledgePoint(
      id: 'kp_organic_aldehyde',
      name: '醛',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第三章 烃的含氧衍生物',
      description: '醛基 -CHO 的化合物(R-CHO)。代表物甲醛、乙醛。'
          '可发生氧化(成羧酸)、还原(成醇)、银镜反应、费林反应。',
      keywords: [
        '醛', '醛类', '甲醛', '蚁醛', '乙醛', '丙醛', '苯甲醛',
        'aldehyde', 'formaldehyde', 'acetaldehyde', 'HCHO', 'CH3CHO',
      ],
      relatedPointIds: ['kp_organic_acid', 'kp_organic_alcohol'],
      functionalGroups: ['C=O', 'CC=O', 'C(=O)'],
      difficulty: 3,
    ),

    // 10. 酮
    KnowledgePoint(
      id: 'kp_organic_ketone',
      name: '酮',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第三章 烃的含氧衍生物',
      description: '羰基 C=O 两端均连烃基的化合物(R-CO-R\')。代表物丙酮。'
          '可发生加成(还原成醇),但不能发生银镜反应。',
      keywords: [
        '酮', '酮类', '丙酮', '丁酮', 'ketone', 'acetone', 'CH3COCH3',
      ],
      relatedPointIds: ['kp_organic_alcohol', 'kp_organic_aldehyde'],
      functionalGroups: ['C(=O)C', 'CC(=O)C'],
      difficulty: 3,
    ),

    // 11. 羧酸
    KnowledgePoint(
      id: 'kp_organic_acid',
      name: '羧酸',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第三章 烃的含氧衍生物',
      description: '羧基 -COOH 的化合物(R-COOH)。代表物甲酸、乙酸(醋酸)。'
          '有弱酸性,可发生酯化反应、中和反应。',
      keywords: [
        '羧酸', '甲酸', '蚁酸', '乙酸', '醋酸', '丙酸', '丁酸', '苯甲酸',
        '羧基', 'carboxylic acid', 'formic acid', 'acetic acid',
        'HCOOH', 'CH3COOH',
      ],
      relatedPointIds: ['kp_organic_ester', 'kp_organic_amide'],
      functionalGroups: ['C(=O)O', 'OC=O', 'O=CO', 'COOH'],
      difficulty: 3,
    ),

    // 12. 酯
    KnowledgePoint(
      id: 'kp_organic_ester',
      name: '酯',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第三章 烃的含氧衍生物',
      description: '羧酸与醇酯化反应产物(R-COOR\')。代表物乙酸乙酯。'
          '可发生水解反应(酸催化可逆,碱催化完全)。',
      keywords: [
        '酯', '酯类', '乙酸乙酯', '甲酸甲酯', '乙酸甲酯', '酯化',
        'ester', 'ethyl acetate', 'CH3COOC2H5',
      ],
      relatedPointIds: ['kp_organic_acid', 'kp_organic_alcohol'],
      functionalGroups: ['C(=O)OC', 'C(=O)OCC', 'COOC'],
      difficulty: 3,
    ),

    // 13. 胺
    KnowledgePoint(
      id: 'kp_organic_amine',
      name: '胺',
      category: 'organic',
      stage: 'college',
      chapter: '有机化学 含氮有机化合物',
      description: '氨分子中氢被烃基取代的产物(R-NH2)。代表物甲胺、乙胺、苯胺。'
          '有弱碱性,可与酸成盐。',
      keywords: [
        '胺', '胺类', '甲胺', '乙胺', '苯胺', '胺基', 'amine',
        'methylamine', 'aniline', 'CH3NH2', 'C6H5NH2',
      ],
      relatedPointIds: ['kp_organic_amide', 'kp_organic_amino_acid'],
      functionalGroups: ['CN', 'C(N)', 'CNC'],
      difficulty: 4,
    ),

    // 14. 酰胺
    KnowledgePoint(
      id: 'kp_organic_amide',
      name: '酰胺',
      category: 'organic',
      stage: 'college',
      chapter: '有机化学 含氮有机化合物',
      description: '羧酸分子中羟基被氨基取代的产物(R-CONH2)。代表物乙酰胺。'
          '可发生水解(成羧酸和胺)。',
      keywords: [
        '酰胺', '乙酰胺', '胺基化合物', 'amide', 'acetamide', 'CH3CONH2',
      ],
      relatedPointIds: ['kp_organic_acid', 'kp_organic_amine'],
      functionalGroups: ['C(=O)N', 'C(=O)NC'],
      difficulty: 4,
    ),

    // 15. 硝基化合物
    KnowledgePoint(
      id: 'kp_organic_nitro',
      name: '硝基化合物',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 (硝化反应)',
      description: '硝基 -NO2 直接连在碳原子上的化合物。代表物硝基苯、TNT。'
          '可还原为胺(如硝基苯还原成苯胺)。',
      keywords: [
        '硝基化合物', '硝基苯', '硝基', 'TNT', '三硝基甲苯', 'nitro',
        'nitrobenzene', 'nitro group', 'NO2',
      ],
      relatedPointIds: ['kp_organic_aromatic', 'kp_organic_amine'],
      functionalGroups: ['N(=O)=O', '[N+](=O)[O-]', 'O=[N+]([O-])'],
      difficulty: 4,
    ),

    // 16. 氨基酸
    KnowledgePoint(
      id: 'kp_organic_amino_acid',
      name: '氨基酸',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第四章 生命中的有机化学',
      description: '同时含氨基 -NH2 和羧基 -COOH 的化合物。代表物甘氨酸、谷氨酸。'
          '是两性化合物,可发生缩合反应成肽键。',
      keywords: [
        '氨基酸', '甘氨酸', '丙氨酸', '谷氨酸', '赖氨酸', '必需氨基酸',
        'amino acid', 'glycine', 'alanine', 'H2NCH2COOH',
      ],
      relatedPointIds: ['kp_organic_protein', 'kp_organic_amine', 'kp_organic_acid'],
      functionalGroups: ['NCC(=O)O', 'NC(=O)O', 'NCC(=O)'],
      difficulty: 4,
    ),

    // 17. 糖类
    KnowledgePoint(
      id: 'kp_organic_carbohydrate',
      name: '糖类',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第四章 生命中的有机化学',
      description: '多羟基醛或多羟基酮及缩合物。分为单糖(葡萄糖/果糖)、'
          '二糖(蔗糖/麦芽糖)、多糖(淀粉/纤维素)。葡萄糖含醛基有还原性。',
      keywords: [
        '糖类', '糖', '葡萄糖', '果糖', '蔗糖', '麦芽糖', '淀粉', '纤维素',
        '碳水化合物', 'carbohydrate', 'glucose', 'fructose', 'sucrose',
        'starch', 'cellulose', 'C6H12O6',
      ],
      relatedPointIds: ['kp_organic_aldehyde', 'kp_organic_alcohol'],
      functionalGroups: ['OCC(O)C(O)C(O)C=O', 'OC1C(O)C(O)C(O)C(O)C1O', 'C(O)C(O)'],
      difficulty: 4,
    ),

    // 18. 杂环化合物
    KnowledgePoint(
      id: 'kp_organic_heterocycle',
      name: '杂环化合物',
      category: 'organic',
      stage: 'college',
      chapter: '有机化学 杂环化合物',
      description: '环上含非碳原子(杂原子如 N/O/S)的环状化合物。'
          '代表物吡啶、呋喃、噻吩、吡咯。许多具有芳香性。',
      keywords: [
        '杂环', '杂环化合物', '吡啶', '呋喃', '噻吩', '吡咯', '吲哚',
        '嘌呤', '嘧啶', 'heterocycle', 'pyridine', 'furan', 'thiophene', 'pyrrole',
      ],
      relatedPointIds: ['kp_organic_aromatic'],
      functionalGroups: ['c1ccncc1', 'c1ccoc1', 'c1ccsc1', 'c1cc[nH]c1'],
      difficulty: 5,
    ),

    // 19. 蛋白质
    KnowledgePoint(
      id: 'kp_organic_protein',
      name: '蛋白质',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第四章 生命中的有机化学',
      description: '由氨基酸通过肽键缩合而成的生物大分子。'
          '具有两性、盐析、变性、颜色反应(双缩脲)等性质。',
      keywords: [
        '蛋白质', '蛋白', '肽键', '多肽', '氨基酸残基', 'protein',
        'peptide', 'enzyme', '酶',
      ],
      relatedPointIds: ['kp_organic_amino_acid', 'kp_organic_polymer'],
      functionalGroups: ['C(=O)NC', 'CNC(=O)'],
      difficulty: 4,
    ),

    // 20. 高分子
    KnowledgePoint(
      id: 'kp_organic_polymer',
      name: '高分子',
      category: 'organic',
      stage: 'highschool,college',
      chapter: '选修5 有机化学基础 第五章 合成有机高分子化合物',
      description: '由单体通过加聚或缩聚反应生成的相对分子质量很大的化合物。'
          '代表物聚乙烯、聚氯乙烯、酚醛树脂。',
      keywords: [
        '高分子', '聚合物', '聚乙烯', '聚氯乙烯', '聚苯乙烯', '酚醛树脂',
        '合成纤维', '塑料', '橡胶', 'polymer', 'polyethylene', 'PVC', 'PE', '聚丙烯',
      ],
      relatedPointIds: ['kp_organic_alkene', 'kp_organic_phenol'],
      functionalGroups: [],
      difficulty: 4,
    ),

    // ==================== 无机化学 inorganic ====================

    // 21. 酸
    KnowledgePoint(
      id: 'kp_inorganic_acid',
      name: '酸',
      category: 'inorganic',
      stage: 'middle,highschool',
      chapter: '九年级下册 第十单元 酸和碱',
      description: '电离时生成的阳离子全部是氢离子(H+)的化合物。'
          '常见酸:盐酸、硫酸、硝酸。具有酸的通性(使紫色石蕊变红等)。',
      keywords: [
        '酸', '盐酸', '硫酸', '硝酸', '碳酸', '磷酸', '醋酸', '酸类',
        '强酸', '弱酸', 'acid', 'HCl', 'H2SO4', 'HNO3', 'H2CO3',
      ],
      relatedPointIds: ['kp_inorganic_salt', 'kp_inorganic_oxide', 'kp_physical_acid_base'],
      functionalGroups: [],
      difficulty: 2,
    ),

    // 22. 碱
    KnowledgePoint(
      id: 'kp_inorganic_base',
      name: '碱',
      category: 'inorganic',
      stage: 'middle,highschool',
      chapter: '九年级下册 第十单元 酸和碱',
      description: '电离时生成的阴离子全部是氢氧根离子(OH-)的化合物。'
          '常见碱:氢氧化钠、氢氧化钙、氨水。',
      keywords: [
        '碱', '氢氧化钠', '氢氧化钙', '氢氧化钾', '烧碱', '火碱', '熟石灰',
        '消石灰', '氨水', '碱类', '强碱', '弱碱', 'base', 'NaOH', 'Ca(OH)2', 'KOH',
      ],
      relatedPointIds: ['kp_inorganic_salt', 'kp_inorganic_oxide', 'kp_physical_acid_base'],
      functionalGroups: [],
      difficulty: 2,
    ),

    // 23. 盐
    KnowledgePoint(
      id: 'kp_inorganic_salt',
      name: '盐',
      category: 'inorganic',
      stage: 'middle,highschool',
      chapter: '九年级下册 第十一单元 盐 化肥',
      description: '由金属离子(或铵根)和酸根离子组成的化合物。'
          '常见盐:氯化钠、碳酸钠、碳酸钙。可发生复分解反应。',
      keywords: [
        '盐', '盐类', '氯化钠', '食盐', '碳酸钠', '纯碱', '苏打', '碳酸钙',
        '石灰石', '硫酸铜', '高锰酸钾', 'salt', 'NaCl', 'Na2CO3', 'CaCO3',
      ],
      relatedPointIds: ['kp_inorganic_acid', 'kp_inorganic_base'],
      functionalGroups: [],
      difficulty: 2,
    ),

    // 24. 氧化物
    KnowledgePoint(
      id: 'kp_inorganic_oxide',
      name: '氧化物',
      category: 'inorganic',
      stage: 'middle,highschool',
      chapter: '九年级上册 第四单元 自然界的水 / 必修一',
      description: '由两种元素组成,其中一种是氧元素的化合物。'
          '分为酸性氧化物(CO2/SO2)、碱性氧化物(CaO/Na2O)、两性氧化物。',
      keywords: [
        '氧化物', '二氧化碳', '一氧化碳', '二氧化硫', '三氧化硫', '氧化钙',
        '生石灰', '氧化铜', '氧化铁', '氧化铝', 'oxide', 'CO2', 'SO2', 'CaO', 'CO', 'Fe2O3',
      ],
      relatedPointIds: ['kp_inorganic_acid', 'kp_inorganic_base'],
      functionalGroups: [],
      difficulty: 2,
    ),

    // 25. 金属
    KnowledgePoint(
      id: 'kp_inorganic_metal',
      name: '金属',
      category: 'inorganic',
      stage: 'middle,highschool',
      chapter: '九年级下册 第八单元 金属和金属材料 / 必修一 第三章',
      description: '具有金属光泽、导电导热、延展性的元素。常见金属:铁、铜、铝。'
          '可与酸/盐溶液发生置换反应,活泼金属可与氧气反应。',
      keywords: [
        '金属', '铁', '铜', '铝', '锌', '镁', '钠', '钾', '钙', '合金',
        '生铁', '钢', 'metal', 'iron', 'copper', 'aluminum', 'Fe', 'Cu', 'Al', 'Zn',
      ],
      relatedPointIds: ['kp_inorganic_oxide', 'kp_inorganic_salt', 'kp_physical_redox'],
      functionalGroups: [],
      difficulty: 2,
    ),

    // 26. 非金属
    KnowledgePoint(
      id: 'kp_inorganic_nonmetal',
      name: '非金属',
      category: 'inorganic',
      stage: 'middle,highschool',
      chapter: '九年级上册 第二单元 我们周围的空气 / 必修一 第四章',
      description: '非金属元素及其单质。常见:氧气、氢气、碳、硫、磷、氯气。'
          '可发生氧化还原反应。',
      keywords: [
        '非金属', '氧气', '氢气', '碳', '硫', '磷', '氯气', '氮气', '臭氧',
        'nonmetal', 'oxygen', 'hydrogen', 'carbon', 'sulfur', 'O2', 'H2', 'Cl2', 'N2',
      ],
      relatedPointIds: ['kp_inorganic_oxide', 'kp_physical_redox'],
      functionalGroups: [],
      difficulty: 2,
    ),

    // 27. 配合物
    KnowledgePoint(
      id: 'kp_inorganic_complex',
      name: '配合物',
      category: 'inorganic',
      stage: 'college',
      chapter: '无机化学 配位化合物',
      description: '由中心离子(或原子)和配体以配位键结合的化合物。'
          '代表物[Cu(NH3)4]SO4、K3[Fe(CN)6]。涉及配位数、空间构型、稳定性。',
      keywords: [
        '配合物', '配位化合物', '络合物', '配离子', '配体', '配位数',
        '中心离子', 'complex', 'coordination compound', '[Cu(NH3)4]', '[Fe(CN)6]',
      ],
      relatedPointIds: [],
      functionalGroups: [],
      difficulty: 5,
    ),

    // ==================== 物理化学 physical ====================

    // 28. 酸碱理论
    KnowledgePoint(
      id: 'kp_physical_acid_base',
      name: '酸碱理论',
      category: 'physical',
      stage: 'highschool,college',
      chapter: '必修一 第二章 化学物质及其变化 / 物理化学',
      description: '酸碱电离理论(阿伦尼乌斯)、质子理论(布朗斯特)、'
          '电子理论(路易斯)。涉及 pH 计算、缓冲溶液、电离平衡。',
      keywords: [
        '酸碱理论', '酸碱', 'pH', '电离', '质子理论', '路易斯酸碱',
        '缓冲溶液', 'acid base theory', 'pH值', '电离平衡',
      ],
      relatedPointIds: ['kp_inorganic_acid', 'kp_inorganic_base'],
      functionalGroups: [],
      difficulty: 3,
    ),

    // 29. 氧化还原
    KnowledgePoint(
      id: 'kp_physical_redox',
      name: '氧化还原',
      category: 'physical',
      stage: 'highschool,college',
      chapter: '必修一 第二章 化学物质及其变化',
      description: '氧化还原反应本质是电子转移。氧化剂得电子被还原,'
          '还原剂失电子被氧化。涉及化合价升降、电子配平。',
      keywords: [
        '氧化还原', '氧化还原反应', '氧化剂', '还原剂', '化合价', '电子转移',
        'redox', 'oxidation', 'reduction',
      ],
      relatedPointIds: ['kp_inorganic_metal', 'kp_inorganic_nonmetal', 'kp_physical_electrochemistry'],
      functionalGroups: [],
      difficulty: 3,
    ),

    // 30. 化学平衡
    KnowledgePoint(
      id: 'kp_physical_equilibrium',
      name: '化学平衡',
      category: 'physical',
      stage: 'highschool,college',
      chapter: '必修二 第二章 化学反应速率与化学平衡 / 物理化学',
      description: '可逆反应中正逆反应速率相等的状态。涉及平衡常数 K、'
          '勒夏特列原理(平衡移动)、转化率。',
      keywords: [
        '化学平衡', '平衡', '平衡常数', '勒夏特列原理', '平衡移动',
        '可逆反应', '化学平衡状态', 'chemical equilibrium', 'Le Chatelier',
      ],
      relatedPointIds: [],
      functionalGroups: [],
      difficulty: 4,
    ),

    // 31. 电化学
    KnowledgePoint(
      id: 'kp_physical_electrochemistry',
      name: '电化学',
      category: 'physical',
      stage: 'highschool,college',
      chapter: '必修二 第二章 化学反应与能量 / 物理化学',
      description: '化学能与电能相互转化。原电池(化学能→电能)、'
          '电解池(电能→化学能)。涉及电极反应、电动势、电解定律。',
      keywords: [
        '电化学', '原电池', '电解池', '电极', '电解', '电镀', '电池',
        '电极电势', 'electrochemistry', 'galvanic cell', 'electrolysis',
      ],
      relatedPointIds: ['kp_inorganic_metal', 'kp_physical_redox'],
      functionalGroups: [],
      difficulty: 4,
    ),
  ];

  /// 知识点 Map (id -> KnowledgePoint)
  static final Map<String, KnowledgePoint> pointMap = {
    for (final kp in allPoints) kp.id: kp,
  };

  /// 按学段过滤(middle / highschool / college)
  /// 多学段知识点 stage 用逗号分隔,如 'highschool,college'
  static List<KnowledgePoint> byStage(String stage) => allPoints
      .where((kp) => kp.stage == stage || kp.stage.contains(stage))
      .toList();

  /// 按分类获取(organic / inorganic / physical)
  static List<KnowledgePoint> byCategory(String category) =>
      allPoints.where((kp) => kp.category == category).toList();

  /// 按 SMILES 匹配知识点(基于官能团模式子串匹配)
  ///
  /// 遍历每个知识点的 functionalGroups,若任一片段是 SMILES 的子串则命中。
  /// 返回命中的知识点列表,按匹配度排序:
  ///   1. 最长命中片段优先(更特异的功能基)
  ///   2. 命中片段数量优先
  ///   3. 命中片段总长度优先
  ///
  /// 注意: 此方法为简化子串匹配,可能产生误匹配(如 'C=O' 同时见于醛/酮),
  /// 排序通过特异度尽量将最相关的知识点排在前面。
  static List<KnowledgePoint> matchBySmiles(String smiles) {
    final s = smiles.trim();
    if (s.isEmpty) return const [];

    final scored = <_SmilesMatch>[];
    for (final kp in allPoints) {
      if (kp.functionalGroups.isEmpty) continue;
      int matchCount = 0;
      int maxLen = 0;
      int totalLen = 0;
      for (final fg in kp.functionalGroups) {
        if (s.contains(fg)) {
          matchCount++;
          totalLen += fg.length;
          if (fg.length > maxLen) maxLen = fg.length;
        }
      }
      if (matchCount > 0) {
        scored.add(_SmilesMatch(kp, matchCount, maxLen, totalLen));
      }
    }

    scored.sort((a, b) {
      final cmpMax = b.maxLen.compareTo(a.maxLen);
      if (cmpMax != 0) return cmpMax;
      final cmpCount = b.matchCount.compareTo(a.matchCount);
      if (cmpCount != 0) return cmpCount;
      return b.totalLen.compareTo(a.totalLen);
    });

    return scored.map((m) => m.point).toList();
  }

  /// 按化合物名匹配知识点(基于关键词)
  ///
  /// 匹配规则(大小写不敏感):
  ///   - 与知识点 name 完全相同: 100 分
  ///   - name 互为包含: 60 分
  ///   - 与某 keyword 完全相同: 90 分
  ///   - 与某 keyword 互为包含: 40 + keyword 长度(更具体的关键词得分更高)
  ///
  /// 返回得分 > 0 的知识点,按得分降序排列。
  static List<KnowledgePoint> matchByName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return const [];

    final scored = <_NameMatch>[];
    for (final kp in allPoints) {
      int score = 0;
      final lowerName = kp.name.toLowerCase();
      if (lowerName == n) {
        score = 100;
      } else if (lowerName.isNotEmpty &&
          (lowerName.contains(n) || n.contains(lowerName))) {
        score = 60;
      }
      for (final kw in kp.keywords) {
        final lkw = kw.toLowerCase();
        if (lkw.isEmpty) continue;
        int kwScore = 0;
        if (lkw == n) {
          kwScore = 90;
        } else if (lkw.contains(n) || n.contains(lkw)) {
          kwScore = 40 + lkw.length;
        }
        if (kwScore > score) score = kwScore;
      }
      if (score > 0) {
        scored.add(_NameMatch(kp, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((m) => m.point).toList();
  }

  /// 获取前置知识点(学习路径推荐用)
  ///
  /// relatedPointIds 表示后继(产物/衍生)节点。若 A 的 relatedPointIds 含 B,
  /// 则 A 是 B 的前置知识点。本方法返回所有将 [pointId] 作为后继的知识点。
  static List<KnowledgePoint> prerequisites(String pointId) =>
      allPoints.where((kp) => kp.relatedPointIds.contains(pointId)).toList();
}

/// SMILES 匹配中间结果
class _SmilesMatch {
  const _SmilesMatch(this.point, this.matchCount, this.maxLen, this.totalLen);

  final KnowledgePoint point;
  final int matchCount;
  final int maxLen;
  final int totalLen;
}

/// 名称匹配中间结果
class _NameMatch {
  const _NameMatch(this.point, this.score);

  final KnowledgePoint point;
  final int score;
}
