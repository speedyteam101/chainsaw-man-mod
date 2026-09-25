using ChainsawManMod.Common.Systems;
using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using System;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs.Bosses
{
	public enum BossMove
	{
		Hover,  // floats above the player
		Circle, // orbits the player
		Walk    // walks on the ground and leaps (gravity, tile collision)
	}

	public enum BossAttack
	{
		Spread,   // aimed volleys of shots in a fan
		Ring,     // rings of shots in every direction
		Spiral,   // a rotating spiral of shots
		Charge,   // dashes at the player (walkers leap instead)
		Summon,   // calls minions
		Rain,     // shots fall from above the player
		Spikes,   // spikes burst out of the ground under the player after a warning
		Teleport  // fades out and reappears beside the player
	}

	// Shared template for the second wave of devil bosses. It moves for a while, then runs the next attack in its
	// list, and repeats. Below half health everything is faster and denser. Sprites are 4 vertical frames.
	// Subclasses need [AutoloadBossHead] themselves (and a <Name>_Head_Boss.png).
	public abstract class DevilBossBase : ModNPC
	{
		private const int FrameCount = 4;
		private const int MaxMinions = 6;
		private const int StateMove = 0; // attack states are (int)BossAttack + 1

		protected abstract BossMove Movement { get; }
		protected abstract BossAttack[] Attacks { get; }
		protected abstract int ShotType { get; }
		protected abstract int Life { get; }
		protected abstract int Damage { get; }
		protected abstract int Defense { get; }
		protected abstract int Width { get; }
		protected abstract int Height { get; }
		protected virtual int MinionType => -1;
		protected virtual int SpikeDust => DustID.Stone;
		protected virtual int HitDust => DustID.Blood;
		protected virtual float ShotSpeed => 9f;
		protected virtual float MoveSpeed => 10f;
		protected virtual int MoveTicks => 100;
		protected virtual int PotionType => ItemID.GreaterHealingPotion;
		protected virtual int MusicTrack => MusicID.Boss2;
		protected virtual int ValueGold => 10;

		// Extra drops on top of Devil Flesh.
		protected abstract void AddLoot(NPCLoot npcLoot);

		private ref float Timer => ref NPC.ai[0];
		private ref float State => ref NPC.ai[1];
		private ref float NextAttack => ref NPC.ai[2];
		private ref float Counter => ref NPC.ai[3];

		protected bool PhaseTwo => NPC.life < NPC.lifeMax / 2;
		private bool Walker => Movement == BossMove.Walk;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
		}

		public override void SetDefaults() {
			NPC.width = Width;
			NPC.height = Height;
			NPC.damage = Damage;
			NPC.defense = Defense;
			NPC.lifeMax = Life;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.knockBackResist = 0f;
			NPC.noGravity = !Walker;
			NPC.noTileCollide = !Walker;
			NPC.value = Item.buyPrice(gold: ValueGold);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 10f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicTrack;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				if (Walker) {
					NPC.velocity.X = MathHelper.Lerp(NPC.velocity.X, -NPC.direction * 4f, 0.05f);
				}
				else {
					NPC.velocity.Y -= 0.2f;
				}
				NPC.EncourageDespawn(10);
				return;
			}

			NPC.direction = NPC.spriteDirection = player.Center.X > NPC.Center.X ? 1 : -1;
			Timer++;

			// Walkers left far behind catch up by teleporting.
			if (Walker && State == StateMove && Vector2.Distance(NPC.Center, player.Center) > 1400f) {
				SetState((int)BossAttack.Teleport + 1);
			}

			if (State == StateMove) {
				Move(player);
				if (Timer >= (PhaseTwo ? MoveTicks * 2 / 3 : MoveTicks)) {
					SetState((int)Attacks[(int)NextAttack % Attacks.Length] + 1);
					NextAttack++;
				}
				return;
			}

			bool done = (BossAttack)((int)State - 1) switch {
				BossAttack.Spread => Spread(player),
				BossAttack.Ring => Ring(),
				BossAttack.Spiral => Spiral(),
				BossAttack.Charge => Charge(player),
				BossAttack.Summon => Summon(),
				BossAttack.Rain => Rain(player),
				BossAttack.Spikes => Spikes(player),
				BossAttack.Teleport => Teleport(player),
				_ => true
			};
			if (done) {
				SetState(StateMove);
			}
		}

		private void Move(Player player) {
			NPC.alpha = Math.Max(0, NPC.alpha - 15);
			float speed = PhaseTwo ? MoveSpeed * 1.3f : MoveSpeed;
			switch (Movement) {
				case BossMove.Hover:
					DevilUtils.FlyToward(NPC, player.Center + new Vector2((float)Math.Sin(Timer / 40f) * 250f, -240f), speed, 20f);
					break;
				case BossMove.Circle:
					DevilUtils.FlyToward(NPC, player.Center + (Timer / 40f).ToRotationVector2() * 360f, speed, 15f);
					break;
				case BossMove.Walk:
					NPC.velocity.X = MathHelper.Lerp(NPC.velocity.X, NPC.direction * speed * 0.3f, 0.1f);
					if (NPC.velocity.Y == 0f && (NPC.collideX || player.Bottom.Y < NPC.Top.Y - 48f)) {
						NPC.velocity.Y = -10f;
					}
					break;
			}
		}

		// Each attack returns true when it has finished.

		private bool Spread(Player player) {
			Brake();
			int volleys = PhaseTwo ? 4 : 3;
			if (Timer % 25 == 10 && Timer < 25 * volleys) {
				int shots = PhaseTwo ? 7 : 5;
				Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY);
				for (int i = 0; i < shots; i++) {
					float angle = MathHelper.ToRadians(11f * (i - (shots - 1) / 2f));
					Fire(NPC.Center, aim.RotatedBy(angle) * ShotSpeed);
				}
			}
			return Timer >= 25 * volleys + 15;
		}

		private bool Ring() {
			Brake();
			int rings = PhaseTwo ? 3 : 2;
			if (Timer % 30 == 15 && Timer < 30 * rings) {
				int shots = PhaseTwo ? 18 : 12;
				float offset = Timer * 0.2f;
				for (int i = 0; i < shots; i++) {
					Fire(NPC.Center, (offset + MathHelper.TwoPi * i / shots).ToRotationVector2() * ShotSpeed * 0.8f);
				}
				SoundEngine.PlaySound(SoundID.Item8, NPC.Center);
			}
			return Timer >= 30 * rings + 20;
		}

		private bool Spiral() {
			Brake();
			if (Timer % (PhaseTwo ? 5 : 7) == 0) {
				int arms = PhaseTwo ? 3 : 2;
				for (int i = 0; i < arms; i++) {
					float angle = Timer * 0.13f + MathHelper.TwoPi * i / arms;
					Fire(NPC.Center, angle.ToRotationVector2() * ShotSpeed * 0.8f);
				}
			}
			return Timer >= 150;
		}

		private bool Charge(Player player) {
			int charges = PhaseTwo ? 3 : 2;
			int t = (int)Timer % 60;
			if (t == 20) {
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
				Vector2 dir = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitX);
				if (Walker) {
					NPC.velocity = new Vector2(MathHelper.Clamp((player.Center.X - NPC.Center.X) / 35f, -12f, 12f), -13f); // leap
				}
				else {
					NPC.velocity = dir * (PhaseTwo ? 24f : 19f);
				}
				NPC.netUpdate = true;
			}
			else if (t < 20 && !Walker) {
				NPC.velocity *= 0.85f;
			}
			return Timer >= 60 * charges;
		}

		private bool Summon() {
			Brake();
			if (Timer == 20 && MinionType >= 0 && DevilUtils.CountActive(MinionType) < MaxMinions) {
				int count = PhaseTwo ? 3 : 2;
				for (int i = 0; i < count; i++) {
					DevilUtils.SpawnMinion(NPC, MinionType, NPC.Center + new Vector2(Main.rand.NextFloat(-100f, 100f), -40f));
				}
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
			}
			return Timer >= 50;
		}

		private bool Rain(Player player) {
			Brake();
			if (Timer % (PhaseTwo ? 6 : 9) == 0) {
				Vector2 start = player.Center + new Vector2(Main.rand.NextFloat(-500f, 500f), -560f);
				Fire(start, new Vector2(Main.rand.NextFloat(-1f, 1f), ShotSpeed * 0.6f), gravity: true);
			}
			return Timer >= 150;
		}

		private bool Spikes(Player player) {
			Brake();
			if (Timer == 10) {
				int count = PhaseTwo ? 6 : 4;
				for (int i = 0; i < count; i++) {
					float offset = (i - (count - 1) / 2f) * 70f + player.velocity.X * 20f;
					// Spawned centred on the point, so lift by half the spike's height to stand on the player's feet level.
					DevilUtils.Shoot(NPC, player.Bottom + new Vector2(offset, -40f), Vector2.Zero,
						ModContent.ProjectileType<GroundSpike>(), NPC.damage / 3);
				}
			}
			return Timer >= 80;
		}

		private bool Teleport(Player player) {
			Brake();
			if (Timer < 30) {
				NPC.alpha = Math.Min(255, NPC.alpha + 9);
			}
			if (Timer == 30 && Main.netMode != NetmodeID.MultiplayerClient) {
				float side = Main.rand.NextBool() ? 1f : -1f;
				NPC.Center = Walker
					? new Vector2(player.Center.X + side * 300f, player.Bottom.Y - NPC.height / 2f)
					: player.Center + new Vector2(side * 320f, -120f);
				NPC.velocity = Vector2.Zero;
				NPC.netUpdate = true;
			}
			if (Timer > 30) {
				NPC.alpha = Math.Max(0, NPC.alpha - 20);
			}
			return Timer >= 50;
		}

		private void Brake() {
			if (Walker) {
				NPC.velocity.X *= 0.85f;
			}
			else {
				NPC.velocity *= 0.92f;
			}
		}

		private void Fire(Vector2 position, Vector2 velocity, bool gravity = false) {
			DevilUtils.Shoot(NPC, position, velocity, ShotType, NPC.damage / 3, gravity ? 1f : 0f);
		}

		private void SetState(int state) {
			State = state;
			Timer = 0f;
			NPC.netUpdate = true;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter += State == (int)BossAttack.Charge + 1 ? 2 : 1;
			if (NPC.frameCounter >= 7) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override bool CanHitPlayer(Player target, ref int cooldownSlot) {
			cooldownSlot = ImmunityCooldownID.Bosses;
			return NPC.alpha < 150; // not while faded out mid-teleport
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 20, 40));
			AddLoot(npcLoot);
		}

		public override void BossLoot(ref int potionType) {
			potionType = PotionType;
		}

		public override void OnKill() {
			DownedDevilSystem.MarkDowned(Name);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary." + Name)
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit, HitDust);
		}
	}
}
