import type { GeneratedCard, LearningItem } from "./generator.js";

export type SeedLearningContent = {
  items: LearningItem[];
  cards: GeneratedCard[];
};

export function seedLearningContent(languageCode: string): SeedLearningContent {
  if (languageCode === "es") return withGoalStarterContent(spanishSeed(languageCode), languageCode);
  if (languageCode === "ru") return withGoalStarterContent(russianSeed(), languageCode);
  if (languageCode === "en") return withGoalStarterContent(englishSeed(), languageCode);
  const seed = starterSeeds[languageCode];
  if (!seed) {
    throw new Error(`Unsupported seed language: ${languageCode}`);
  }
  return withGoalStarterContent(basicSeed(seed), languageCode);
}

type BasicSeed = {
  code: string;
  coffeeRequest: string;
  coffeeRequestPrompt: string;
  toGo: string;
  toGoPrompt: string;
  toGoOptions: string[];
  student: string;
  studentMistake: string;
  thankYou: string;
  chatMessage: string;
};

const starterSeeds: Record<string, BasicSeed> = {
  de: {
    code: "de",
    coffeeRequest: "Ich mochte Kaffee",
    coffeeRequestPrompt: "Я хочу кофе.",
    toGo: "zum Mitnehmen",
    toGoPrompt: "Kaffee ___, bitte.",
    toGoOptions: ["zum Mitnehmen", "gestern", "blau", "hoch"],
    student: "Ich bin Student",
    studentMistake: "Ich ist Student.",
    thankYou: "Danke",
    chatMessage: "Hier ist Ihr Kaffee.",
  },
  fr: {
    code: "fr",
    coffeeRequest: "Je veux du cafe",
    coffeeRequestPrompt: "Я хочу кофе.",
    toGo: "a emporter",
    toGoPrompt: "Cafe ___, s'il vous plait.",
    toGoOptions: ["a emporter", "hier", "bleu", "grand"],
    student: "Je suis etudiant",
    studentMistake: "Je est etudiant.",
    thankYou: "Merci",
    chatMessage: "Voici votre cafe.",
  },
  it: {
    code: "it",
    coffeeRequest: "Voglio un caffe",
    coffeeRequestPrompt: "Я хочу кофе.",
    toGo: "da portare via",
    toGoPrompt: "Caffe ___, per favore.",
    toGoOptions: ["da portare via", "ieri", "blu", "alto"],
    student: "Io sono studente",
    studentMistake: "Io e studente.",
    thankYou: "Grazie",
    chatMessage: "Ecco il tuo caffe.",
  },
  pt: {
    code: "pt",
    coffeeRequest: "Eu quero cafe",
    coffeeRequestPrompt: "Я хочу кофе.",
    toGo: "para viagem",
    toGoPrompt: "Cafe ___, por favor.",
    toGoOptions: ["para viagem", "ontem", "azul", "alto"],
    student: "Eu sou estudante",
    studentMistake: "Eu e estudante.",
    thankYou: "Obrigado",
    chatMessage: "Aqui esta o seu cafe.",
  },
  ja: {
    code: "ja",
    coffeeRequest: "コーヒーが欲しいです",
    coffeeRequestPrompt: "Я хочу кофе.",
    toGo: "持ち帰り",
    toGoPrompt: "コーヒーを___でお願いします。",
    toGoOptions: ["持ち帰り", "昨日", "青い", "高い"],
    student: "私は学生です",
    studentMistake: "私は学生ある。",
    thankYou: "ありがとうございます",
    chatMessage: "こちらがコーヒーです。",
  },
  ko: {
    code: "ko",
    coffeeRequest: "커피를 원해요",
    coffeeRequestPrompt: "Я хочу кофе.",
    toGo: "테이크아웃",
    toGoPrompt: "커피 ___ 부탁해요.",
    toGoOptions: ["테이크아웃", "어제", "파란색", "높은"],
    student: "저는 학생이에요",
    studentMistake: "저는 학생이다요.",
    thankYou: "감사합니다",
    chatMessage: "여기 커피입니다.",
  },
  "zh-Hans": {
    code: "zh-Hans",
    coffeeRequest: "我想要咖啡",
    coffeeRequestPrompt: "Я хочу кофе.",
    toGo: "带走",
    toGoPrompt: "咖啡___，谢谢。",
    toGoOptions: ["带走", "昨天", "蓝色", "高"],
    student: "我是学生",
    studentMistake: "我是一个学生吗。",
    thankYou: "谢谢",
    chatMessage: "这是你的咖啡。",
  },
};

function basicSeed(seed: BasicSeed): SeedLearningContent {
  const languageCode = seed.code;
  const items: LearningItem[] = [
    {
      id: `${languageCode}_phrase_coffee_request`,
      kind: "phrase",
      languageCode,
      value: seed.coffeeRequest,
      translation: "I want coffee",
      tags: ["coffee", "ordering"],
      level: "A1",
    },
    {
      id: `${languageCode}_phrase_to_go`,
      kind: "phrase",
      languageCode,
      value: seed.toGo,
      translation: "to go",
      tags: ["coffee", "restaurant"],
      level: "A1",
    },
    {
      id: `${languageCode}_grammar_i_am_student`,
      kind: "grammarPattern",
      languageCode,
      value: seed.student,
      translation: "I am a student",
      tags: ["introductions", "grammar"],
      level: "A1",
    },
    {
      id: `${languageCode}_phrase_thank_you`,
      kind: "phrase",
      languageCode,
      value: seed.thankYou,
      translation: "thank you",
      tags: ["chat"],
      level: "A1",
    },
  ];

  const cards: GeneratedCard[] = [
    {
      id: `${languageCode}_coffee_translate_i_want_coffee`,
      type: "translate",
      context: "A1 / coffee run",
      situation: "Закажите кофе в маленькой кофейне.",
      prompt: seed.coffeeRequestPrompt,
      options: [],
      correctAnswer: seed.coffeeRequest,
      explanation: `${seed.coffeeRequest} means I want coffee.`,
      chatMessages: [],
      targetItemIDs: [`${languageCode}_phrase_coffee_request`],
      skillTags: ["coffee", "ordering"],
      difficulty: 1,
      missionID: `${languageCode}_mission_coffee`,
    },
    {
      id: `${languageCode}_coffee_gap_to_go`,
      type: "fillGap",
      context: "A1 / coffee run",
      situation: "Попросите кофе с собой.",
      prompt: seed.toGoPrompt,
      options: seed.toGoOptions,
      correctAnswer: seed.toGo,
      explanation: `${seed.toGo} means to go.`,
      chatMessages: [],
      targetItemIDs: [`${languageCode}_phrase_to_go`],
      skillTags: ["coffee", "restaurant"],
      difficulty: 1,
      missionID: `${languageCode}_mission_coffee`,
    },
    {
      id: `${languageCode}_intro_fix_i_am`,
      type: "fixMistake",
      context: "A1 / introductions",
      situation: "Представьтесь собеседнику.",
      prompt: `Исправьте ошибку: ${seed.studentMistake}`,
      options: [],
      correctAnswer: seed.student,
      explanation: `Use the natural pattern: ${seed.student}.`,
      chatMessages: [],
      targetItemIDs: [`${languageCode}_grammar_i_am_student`],
      skillTags: ["introductions", "grammar"],
      difficulty: 1,
      missionID: `${languageCode}_mission_intro`,
    },
    {
      id: `${languageCode}_chat_thank_you`,
      type: "chat",
      context: "A1 / chat",
      situation: "Бариста отдает вам кофе.",
      prompt: "Choose the natural reply.",
      options: [seed.thankYou, ...seed.toGoOptions.slice(1, 4)],
      correctAnswer: seed.thankYou,
      explanation: `${seed.thankYou} is the natural reply after receiving something.`,
      chatMessages: [{ id: `${languageCode}_chat_thank_you_prompt`, text: seed.chatMessage, isUser: false }],
      targetItemIDs: [`${languageCode}_phrase_thank_you`],
      skillTags: ["chat", "coffee"],
      difficulty: 1,
      missionID: `${languageCode}_mission_coffee`,
    },
  ];

  return { items, cards };
}

function spanishSeed(languageCode: string): SeedLearningContent {
  const items: LearningItem[] = [
    {
      id: `${languageCode}_lexeme_quiero`,
      kind: "lexeme",
      languageCode,
      value: "quiero",
      translation: "I want",
      tags: ["coffee", "ordering"],
      level: "A1",
    },
    {
      id: `${languageCode}_lexeme_cafe`,
      kind: "lexeme",
      languageCode,
      value: "cafe",
      translation: "coffee",
      tags: ["coffee"],
      level: "A1",
    },
    {
      id: `${languageCode}_phrase_para_llevar`,
      kind: "phrase",
      languageCode,
      value: "para llevar",
      translation: "to go",
      tags: ["coffee", "restaurant"],
      level: "A1",
    },
    {
      id: `${languageCode}_grammar_yo_soy`,
      kind: "grammarPattern",
      languageCode,
      value: "Yo soy estudiante",
      translation: "I am",
      tags: ["introductions"],
      level: "A1",
    },
    {
      id: `${languageCode}_phrase_gracias`,
      kind: "phrase",
      languageCode,
      value: "gracias",
      translation: "thank you",
      tags: ["chat"],
      level: "A1",
    },
  ];

  const cards: GeneratedCard[] = [
    {
      id: `${languageCode}_coffee_translate_quiero_cafe`,
      type: "translate",
      context: "A1 / coffee run",
      situation: "You are ordering at a small cafe.",
      prompt: "I want coffee.",
      options: [],
      correctAnswer: "Quiero cafe",
      explanation: "Quiero means I want.",
      chatMessages: [],
      targetItemIDs: [`${languageCode}_lexeme_quiero`, `${languageCode}_lexeme_cafe`],
      skillTags: ["coffee", "ordering"],
      difficulty: 1,
      missionID: `${languageCode}_mission_coffee`,
    },
    {
      id: `${languageCode}_coffee_gap_para_llevar`,
      type: "fillGap",
      context: "A1 / coffee run",
      situation: "You want the coffee to go.",
      prompt: "Un cafe ___, por favor.",
      options: ["para llevar", "ayer", "azul", "alto"],
      correctAnswer: "para llevar",
      explanation: "Para llevar means to go or takeaway.",
      chatMessages: [],
      targetItemIDs: [`${languageCode}_phrase_para_llevar`],
      skillTags: ["coffee", "restaurant"],
      difficulty: 1,
      missionID: `${languageCode}_mission_coffee`,
    },
    {
      id: `${languageCode}_intro_fix_yo_soy`,
      type: "fixMistake",
      context: "A1 / introductions",
      situation: "You are introducing yourself.",
      prompt: "Исправьте ошибку: Yo es estudiante.",
      options: [],
      correctAnswer: "Yo soy estudiante",
      explanation: "Use soy with yo for identity or profession.",
      chatMessages: [],
      targetItemIDs: [`${languageCode}_grammar_yo_soy`],
      skillTags: ["introductions", "grammar"],
      difficulty: 1,
      missionID: `${languageCode}_mission_intro`,
    },
    {
      id: `${languageCode}_chat_gracias`,
      type: "chat",
      context: "A1 / chat",
      situation: "The barista gives you your coffee.",
      prompt: "Choose the natural reply.",
      options: ["Gracias", "Buenas noches", "Tengo dos", "Hasta ayer"],
      correctAnswer: "Gracias",
      explanation: "Gracias is the direct, natural reply after receiving something.",
      chatMessages: [{ id: `${languageCode}_chat_gracias_prompt`, text: "Aqui tienes tu cafe.", isUser: false }],
      targetItemIDs: [`${languageCode}_phrase_gracias`],
      skillTags: ["chat", "coffee"],
      difficulty: 1,
      missionID: `${languageCode}_mission_coffee`,
    },
  ];

  return { items, cards };
}

function russianSeed(): SeedLearningContent {
  const languageCode = "ru";
  const items: LearningItem[] = [
    {
      id: "ru_lexeme_ya",
      kind: "lexeme",
      languageCode,
      value: "я",
      translation: "I",
      tags: ["introductions", "grammar"],
      level: "A1",
    },
    {
      id: "ru_lexeme_hochu",
      kind: "lexeme",
      languageCode,
      value: "хочу",
      translation: "want",
      tags: ["coffee", "ordering"],
      level: "A1",
    },
    {
      id: "ru_lexeme_kofe",
      kind: "lexeme",
      languageCode,
      value: "кофе",
      translation: "coffee",
      tags: ["coffee"],
      level: "A1",
    },
    {
      id: "ru_phrase_s_soboy",
      kind: "phrase",
      languageCode,
      value: "с собой",
      translation: "to go",
      tags: ["coffee", "restaurant"],
      level: "A1",
    },
    {
      id: "ru_phrase_spasibo",
      kind: "phrase",
      languageCode,
      value: "спасибо",
      translation: "thank you",
      tags: ["chat"],
      level: "A1",
    },
    {
      id: "ru_lexeme_student",
      kind: "lexeme",
      languageCode,
      value: "студент",
      translation: "student",
      tags: ["introductions"],
      level: "A1",
    },
  ];

  const cards: GeneratedCard[] = [
    {
      id: "ru_coffee_translate_ya_hochu_kofe",
      type: "translate",
      context: "A1 / coffee run",
      situation: "You are ordering at a small cafe.",
      prompt: "I want coffee.",
      options: [],
      correctAnswer: "Я хочу кофе",
      explanation: "Я means I, хочу means want, and кофе means coffee.",
      chatMessages: [],
      targetItemIDs: ["ru_lexeme_ya", "ru_lexeme_hochu", "ru_lexeme_kofe"],
      skillTags: ["coffee", "ordering"],
      difficulty: 1,
      missionID: "ru_mission_coffee",
    },
    {
      id: "ru_coffee_gap_s_soboy",
      type: "fillGap",
      context: "A1 / coffee run",
      situation: "You want the coffee to go.",
      prompt: "Кофе ___, пожалуйста.",
      options: ["с собой", "вчера", "синий", "высокий"],
      correctAnswer: "с собой",
      explanation: "С собой means to go or takeaway.",
      chatMessages: [],
      targetItemIDs: ["ru_phrase_s_soboy"],
      skillTags: ["coffee", "restaurant"],
      difficulty: 1,
      missionID: "ru_mission_coffee",
    },
    {
      id: "ru_intro_fix_ya_student",
      type: "fixMistake",
      context: "A1 / introductions",
      situation: "You are introducing yourself.",
      prompt: "Исправьте ошибку: Я студентом.",
      options: [],
      correctAnswer: "Я студент",
      explanation: "In Russian, you usually do not use есть for identity in the present tense.",
      chatMessages: [],
      targetItemIDs: ["ru_lexeme_ya", "ru_lexeme_student"],
      skillTags: ["introductions", "grammar"],
      difficulty: 1,
      missionID: "ru_mission_intro",
    },
    {
      id: "ru_chat_spasibo",
      type: "chat",
      context: "A1 / chat",
      situation: "The barista gives you your coffee.",
      prompt: "Choose the natural reply.",
      options: ["Спасибо", "Доброй ночи", "У меня два", "До вчера"],
      correctAnswer: "Спасибо",
      explanation: "Спасибо is the direct, natural reply after receiving something.",
      chatMessages: [{ id: "ru_chat_spasibo_prompt", text: "Вот ваш кофе.", isUser: false }],
      targetItemIDs: ["ru_phrase_spasibo"],
      skillTags: ["chat", "coffee"],
      difficulty: 1,
      missionID: "ru_mission_coffee",
    },
  ];

  return { items, cards };
}

function englishSeed(): SeedLearningContent {
  const languageCode = "en";
  const items: LearningItem[] = [
    {
      id: "en_lexeme_i",
      kind: "lexeme",
      languageCode,
      value: "I",
      translation: "я",
      tags: ["introductions", "grammar"],
      level: "A1",
    },
    {
      id: "en_lexeme_want",
      kind: "lexeme",
      languageCode,
      value: "want",
      translation: "хотеть",
      tags: ["coffee", "ordering"],
      level: "A1",
    },
    {
      id: "en_lexeme_coffee",
      kind: "lexeme",
      languageCode,
      value: "coffee",
      translation: "кофе",
      tags: ["coffee"],
      level: "A1",
    },
    {
      id: "en_phrase_to_go",
      kind: "phrase",
      languageCode,
      value: "to go",
      translation: "с собой",
      tags: ["coffee", "restaurant"],
      level: "A1",
    },
    {
      id: "en_phrase_thank_you",
      kind: "phrase",
      languageCode,
      value: "thank you",
      translation: "спасибо",
      tags: ["chat"],
      level: "A1",
    },
    {
      id: "en_lexeme_student",
      kind: "lexeme",
      languageCode,
      value: "student",
      translation: "студент",
      tags: ["introductions"],
      level: "A1",
    },
    {
      id: "en_grammar_i_am_student",
      kind: "grammarPattern",
      languageCode,
      value: "I am a student",
      translation: "я студент",
      tags: ["introductions", "grammar"],
      level: "A1",
    },
  ];

  const cards: GeneratedCard[] = [
    {
      id: "en_coffee_translate_i_want_coffee",
      type: "translate",
      context: "A1 / coffee run",
      situation: "Закажите кофе в маленькой кофейне.",
      prompt: "Я хочу кофе.",
      options: [],
      correctAnswer: "I want coffee",
      explanation: "I want means я хочу.",
      chatMessages: [],
      targetItemIDs: ["en_lexeme_i", "en_lexeme_want", "en_lexeme_coffee"],
      skillTags: ["coffee", "ordering"],
      difficulty: 1,
      missionID: "en_mission_coffee",
    },
    {
      id: "en_coffee_gap_to_go",
      type: "fillGap",
      context: "A1 / coffee run",
      situation: "Попросите кофе с собой.",
      prompt: "Coffee ___, please.",
      options: ["to go", "yesterday", "blue", "tall"],
      correctAnswer: "to go",
      explanation: "To go means с собой.",
      chatMessages: [],
      targetItemIDs: ["en_phrase_to_go"],
      skillTags: ["coffee", "restaurant"],
      difficulty: 1,
      missionID: "en_mission_coffee",
    },
    {
      id: "en_intro_fix_i_am",
      type: "fixMistake",
      context: "A1 / introductions",
      situation: "Представьтесь собеседнику.",
      prompt: "Исправьте ошибку: I is a student.",
      options: [],
      correctAnswer: "I am a student",
      explanation: "Use am with I.",
      chatMessages: [],
      targetItemIDs: ["en_grammar_i_am_student"],
      skillTags: ["introductions", "grammar"],
      difficulty: 1,
      missionID: "en_mission_intro",
    },
    {
      id: "en_chat_thank_you",
      type: "chat",
      context: "A1 / chat",
      situation: "Бариста отдает вам кофе.",
      prompt: "Choose the natural reply.",
      options: ["Thank you", "Good night", "I have two", "Until yesterday"],
      correctAnswer: "Thank you",
      explanation: "Thank you is the natural reply after receiving something.",
      chatMessages: [{ id: "en_chat_thank_you_prompt", text: "Here is your coffee.", isUser: false }],
      targetItemIDs: ["en_phrase_thank_you"],
      skillTags: ["chat", "coffee"],
      difficulty: 1,
      missionID: "en_mission_coffee",
    },
  ];

  return { items, cards };
}

type GoalID = "travel" | "work" | "dating" | "relocation" | "study" | "everyday";

const goalIDs: GoalID[] = ["travel", "work", "dating", "relocation", "study", "everyday"];

const goalMeanings: Record<GoalID, string> = {
  travel: "У меня бронь.",
  work: "У меня встреча.",
  dating: "Приятно познакомиться.",
  relocation: "Мне нужны документы.",
  study: "У меня занятие.",
  everyday: "Где магазин?",
};

const goalSituations: Record<GoalID, string> = {
  travel: "В поездке нужна понятная фраза.",
  work: "На работе нужна понятная фраза.",
  dating: "При знакомстве нужен естественный ответ.",
  relocation: "При оформлении документов нужна понятная фраза.",
  study: "На учебе нужна понятная фраза.",
  everyday: "В городе нужна понятная фраза.",
};

const goalChatMessages: Record<GoalID, string> = {
  travel: "The receptionist asks what you need.",
  work: "A coworker asks why you are leaving.",
  dating: "Someone says: Nice to meet you.",
  relocation: "The clerk asks what you need.",
  study: "A classmate asks about your schedule.",
  everyday: "Someone asks what place you need.",
};

const goalStarterValues: Record<string, Record<GoalID, string>> = {
  en: {
    travel: "I have a reservation",
    work: "I have a meeting",
    dating: "Nice to meet you",
    relocation: "I need documents",
    study: "I have a class",
    everyday: "Where is the store",
  },
  es: {
    travel: "Tengo una reserva",
    work: "Tengo una reunion",
    dating: "Encantado de conocerte",
    relocation: "Necesito documentos",
    study: "Tengo una clase",
    everyday: "Donde esta la tienda",
  },
  ru: {
    travel: "У меня бронь",
    work: "У меня встреча",
    dating: "Приятно познакомиться",
    relocation: "Мне нужны документы",
    study: "У меня занятие",
    everyday: "Где магазин",
  },
  de: {
    travel: "Ich habe eine Reservierung",
    work: "Ich habe ein Meeting",
    dating: "Freut mich",
    relocation: "Ich brauche Dokumente",
    study: "Ich habe Unterricht",
    everyday: "Wo ist der Laden",
  },
  fr: {
    travel: "J'ai une reservation",
    work: "J'ai une reunion",
    dating: "Ravi de vous rencontrer",
    relocation: "J'ai besoin de documents",
    study: "J'ai un cours",
    everyday: "Ou est le magasin",
  },
  it: {
    travel: "Ho una prenotazione",
    work: "Ho una riunione",
    dating: "Piacere di conoscerti",
    relocation: "Ho bisogno di documenti",
    study: "Ho una lezione",
    everyday: "Dove si trova il negozio",
  },
  pt: {
    travel: "Tenho uma reserva",
    work: "Tenho uma reuniao",
    dating: "Prazer em conhecer voce",
    relocation: "Preciso de documentos",
    study: "Tenho uma aula",
    everyday: "Onde fica a loja",
  },
  ja: {
    travel: "予約があります",
    work: "会議があります",
    dating: "はじめまして",
    relocation: "書類が必要です",
    study: "授業があります",
    everyday: "店はどこですか",
  },
  ko: {
    travel: "예약이 있어요",
    work: "회의가 있어요",
    dating: "만나서 반가워요",
    relocation: "서류가 필요해요",
    study: "수업이 있어요",
    everyday: "가게가 어디예요",
  },
  "zh-Hans": {
    travel: "我有预订",
    work: "我有会议",
    dating: "很高兴认识你",
    relocation: "我需要文件",
    study: "我有课",
    everyday: "商店在哪里",
  },
};

function withGoalStarterContent(content: SeedLearningContent, languageCode: string): SeedLearningContent {
  const goalValues = goalStarterValues[languageCode];
  if (!goalValues) return content;

  const goalItems = goalIDs.map((goal): LearningItem => ({
    id: `${languageCode}_goal_${goal}`,
    kind: "phrase",
    languageCode,
    value: goalValues[goal],
    translation: goalMeanings[goal],
    tags: [goal, "goal_starter"],
    level: "A1",
  }));
  const optionsByGoal = Object.fromEntries(
    goalIDs.map((goal) => [goal, unique([goalValues[goal], ...goalIDs.filter((other) => other !== goal).map((other) => goalValues[other])]).slice(0, 4)]),
  ) as Record<GoalID, string[]>;
  const goalCards = goalIDs.flatMap((goal): GeneratedCard[] => [
    {
      id: `${languageCode}_goal_${goal}_translate`,
      type: "translate",
      context: `A1 / ${goal}`,
      situation: goalSituations[goal],
      prompt: goalMeanings[goal],
      options: [],
      correctAnswer: goalValues[goal],
      explanation: `${goalValues[goal]} = ${goalMeanings[goal]}`,
      chatMessages: [],
      targetItemIDs: [`${languageCode}_goal_${goal}`],
      skillTags: [goal, "goal_starter"],
      difficulty: 1,
      missionID: goal,
    },
    {
      id: `${languageCode}_goal_${goal}_choice`,
      type: "multipleChoice",
      context: `A1 / ${goal}`,
      situation: goalSituations[goal],
      prompt: `Выберите фразу: ${goalMeanings[goal]}`,
      options: optionsByGoal[goal],
      correctAnswer: goalValues[goal],
      explanation: `${goalValues[goal]} = ${goalMeanings[goal]}`,
      chatMessages: [],
      targetItemIDs: [`${languageCode}_goal_${goal}`],
      skillTags: [goal, "goal_starter"],
      difficulty: 1,
      missionID: goal,
    },
    {
      id: `${languageCode}_goal_${goal}_chat`,
      type: "chat",
      context: `A1 / ${goal}`,
      situation: goalSituations[goal],
      prompt: "Choose the phrase for this situation.",
      options: optionsByGoal[goal],
      correctAnswer: goalValues[goal],
      explanation: `${goalValues[goal]} = ${goalMeanings[goal]}`,
      chatMessages: [{ id: `${languageCode}_goal_${goal}_chat_prompt`, text: goalChatMessages[goal], isUser: false }],
      targetItemIDs: [`${languageCode}_goal_${goal}`],
      skillTags: [goal, "goal_starter"],
      difficulty: 1,
      missionID: goal,
    },
  ]);

  return {
    items: [...content.items, ...goalItems],
    cards: [...goalCards, ...content.cards],
  };
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}
