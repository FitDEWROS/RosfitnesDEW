const obj = document.getElementById("bodyFront");

obj.addEventListener("load", () => {
  const svgDoc = obj.contentDocument;

  // 👉 примеры мышц
  const chest = svgDoc.getElementById("chest");
  const abs = svgDoc.getElementById("abs");
  const bicepsLeft = svgDoc.getElementById("biceps-left");
  const bicepsRight = svgDoc.getElementById("biceps-right");

  // Наведение подсвечивает
  [chest, abs, bicepsLeft, bicepsRight].forEach(muscle => {
    if (!muscle) return;
    muscle.addEventListener("mouseenter", () => muscle.style.fill = "red");
    muscle.addEventListener("mouseleave", () => muscle.style.fill = "");
    muscle.addEventListener("click", () => {
      alert("Нажали на: " + muscle.id);
      // тут можно подгружать упражнения из твоего DB
    });
  });
});
